///|
// Lifeguard protocol core — arXiv:1707.00788v2.
// Pure state machine: no IO, no clocks; time enters only as configurable
// millisecond parameters so the whole thing is deterministically testable.

///|
#derive(Eq, @debug.Debug)
pub(all) enum MemberState {
  Alive
  Suspect
  Failed
}

///|
pub extend MemberState with Eq::{ equal, not_equal }
pub extend MemberState with @debug.Debug::{ to_repr }

///|
/// Protocol messages (paper Sections III/IV).
#derive(Eq, @debug.Debug)
pub(all) enum Msg {
  Ping(String, Int) // from, probe seq
  Ack(String, Int) // from, probe seq
  PingReq(String, String, Int) // from, target, probe seq
  Nack(String, Int) // from, probe seq
  Suspect(String, UInt64, String) // about, incarnation, originator
  Alive(String, UInt64, String) // about, incarnation, originator
  Confirm(String, UInt64, String) // about, incarnation, originator
}

///|
pub extend Msg with Eq::{ equal, not_equal }
pub extend Msg with @debug.Debug::{ to_repr }

///|
priv struct Member {
  incarnation : UInt64
  state : MemberState
}

///|
pub struct SwimNode {
  priv id : String
  priv peers : Array[String]
  priv members : @hashmap.HashMap[String, Member]
  priv mut awareness : Int
  priv max_awareness : Int
  priv base_probe_interval_ms : Int
  priv base_probe_timeout_ms : Int
  priv suspicion_alpha : Double
  priv suspicion_beta : Double
  priv suspicion_k : Int
  priv mut next_seq : Int
  priv mut ever_failed_healthy_flag : Bool
}

///|
/// Create a node; `peers` are the other members (cluster size = peers+1).
pub fn SwimNode::new(
  id~ : String,
  peers~ : Array[String],
  base_probe_interval_ms~ : Int,
  base_probe_timeout_ms~ : Int,
  suspicion_alpha~ : Double,
  suspicion_beta~ : Double,
  suspicion_k~ : Int,
  max_awareness~ : Int,
) -> SwimNode {
  let members : @hashmap.HashMap[String, Member] = @hashmap.HashMap([], capacity=16)
  for p in peers {
    members.set(p, { incarnation: 0UL, state: Alive })
  }
  {
    id,
    peers: peers.copy(),
    members,
    awareness: 0,
    max_awareness,
    base_probe_interval_ms,
    base_probe_timeout_ms,
    suspicion_alpha,
    suspicion_beta,
    suspicion_k,
    next_seq: 1,
    ever_failed_healthy_flag: false,
  }
}

///|
/// Local Health Awareness counter (paper: saturated 0..S, S=8).
pub fn SwimNode::awareness(self : SwimNode) -> Int {
  self.awareness
}

///|
fn SwimNode::bump(self : SwimNode, d : Int) -> Unit {
  let v = self.awareness + d
  self.awareness = if v < 0 {
    0
  } else if v > self.max_awareness {
    self.max_awareness
  } else {
    v
  }
}

///|
pub fn SwimNode::record_ack(self : SwimNode) -> Unit {
  self.bump(-1) // successful probe: -1
}

///|
pub fn SwimNode::record_probe_fail(self : SwimNode) -> Unit {
  self.bump(1) // failed probe: +1
}

///|
pub fn SwimNode::record_refute(self : SwimNode) -> Unit {
  self.bump(1) // refuting a suspicion about self: +1
}

///|
pub fn SwimNode::record_missed_nack(self : SwimNode) -> Unit {
  self.bump(1) // missed nack: +1
}

///|
pub fn SwimNode::self_incarnation(self : SwimNode) -> UInt64 {
  match self.members.get(self.id) {
    Some(m) => m.incarnation
    None => 0UL
  }
}

///|
fn SwimNode::take_seq(self : SwimNode) -> Int {
  let s = self.next_seq
  self.next_seq = s + 1
  s
}

///|
/// ProbeInterval = Base * (LHM+1); ProbeTimeout likewise.
pub fn SwimNode::probe_interval_ms(self : SwimNode) -> Int {
  self.base_probe_interval_ms * (self.awareness + 1)
}

///|
pub fn SwimNode::probe_timeout_ms(self : SwimNode) -> Int {
  self.base_probe_timeout_ms * (self.awareness + 1)
}

///|
/// Min = alpha * log10(n) * ProbeInterval, n = total member count.
pub fn SwimNode::suspicion_min_ms(self : SwimNode) -> Int {
  let n = (self.peers.length() + 1).to_double()
  let v = self.suspicion_alpha * @math.log10(n) * self.probe_interval_ms().to_double()
  v.to_int()
}

///|
/// SuspicionTimeout = max(Min, Max - (Max-Min) * ln(C+1)/ln(K+1)).
/// C = independent suspect messages received since local suspicion began.
pub fn SwimNode::suspicion_timeout_ms(self : SwimNode, independent_count : Int) -> Int {
  let min = self.suspicion_min_ms()
  let max = (self.suspicion_beta * min.to_double()).to_int()
  if independent_count >= self.suspicion_k {
    return min
  }
  let decay = @math.ln((independent_count + 1).to_double()) / @math.ln(
      (self.suspicion_k + 1).to_double(),
    )
  let t = max.to_double() - (max - min).to_double() * decay
  let ti = t.to_int()
  if ti < min {
    min
  } else {
    ti
  }
}

///|
pub fn SwimNode::member_state(self : SwimNode, id : String) -> Option[MemberState] {
  self.members.get(id).map(fn(m) { m.state })
}

///|
pub fn SwimNode::member_incarnation(self : SwimNode, id : String) -> Option[UInt64] {
  self.members.get(id).map(fn(m) { m.incarnation })
}

///|
pub fn SwimNode::ever_failed_healthy(self : SwimNode) -> Bool {
  self.ever_failed_healthy_flag
}

///|
/// Next probe sequence number for starting a new probe round.
pub fn SwimNode::start_probe(self : SwimNode) -> Int {
  self.take_seq()
}

///|
/// Apply a membership message (Suspect/Alive/Confirm semantics);
/// returns messages to relay onward.
pub fn SwimNode::handle(self : SwimNode, msg : Msg) -> Array[Msg] {
  let out : Array[Msg] = []
  match msg {
    Suspect(about, inc, origin) =>
      if about == self.id {
        // I am suspected: refute with incarnation+1 (paper IV-C)
        let mine = self.self_incarnation()
        if inc >= mine {
          self.members.set(self.id, { incarnation: mine + 1UL, state: Alive })
          self.record_refute()
          out.push(Alive(self.id, mine + 1UL, self.id))
        }
      } else if origin != about {
        match self.members.get(about) {
          Some(m) =>
            if inc >= m.incarnation && m.state == Alive {
              self.members.set(about, { incarnation: m.incarnation, state: Suspect })
              out.push(msg)
            }
          None => ()
        }
      }
    Alive(about, inc, _origin) =>
      if about != self.id {
        match self.members.get(about) {
          Some(m) =>
            // only a strictly higher incarnation overrides suspect/alive
            // (the incarnation bump itself can only be minted by `about`)
            if inc > m.incarnation && m.state != Failed {
              self.members.set(about, { incarnation: inc, state: Alive })
              out.push(msg)
            }
          None => ()
        }
      }
    Confirm(about, inc, origin) =>
      if about != self.id && origin != about {
        match self.members.get(about) {
          Some(m) =>
            if inc >= m.incarnation && m.state != Failed {
              if m.state == Alive {
                self.ever_failed_healthy_flag = true
              }
              self.members.set(about, { incarnation: m.incarnation, state: Failed })
              out.push(msg)
            }
          None => ()
        }
      }
    Ping(_, _) | Ack(_, _) | PingReq(_, _, _) | Nack(_, _) => ()
  }
  out
}
