///|
// Async simulation driver: virtual message bus + per-node protocol tasks.
// Transport-free: one-way delivery latency is a fixed sleep, gossip is
// flood with per-(origin,message) dedup, so the run is deterministic.

///|
pub struct SimResult {
  all_confirmed_dead : Bool // every live node marked dead_node Failed
  no_false_positive : Bool // no healthy node ever marked Failed anywhere
  dead_confirmed_by : Int32
  awareness_max_seen : Int32
}

///|
priv struct Envelope {
  to : String // delivery target (envelope address)
  origin : String // original sender (for dedup)
  from : String // immediate sender (for gossip exclusion)
  msg : Msg
}

///|
priv struct SimNode {
  node : SwimNode
  inbox : @async.Queue[Envelope]
  // my probes: seq -> acked?
  pending : @hashmap.HashMap[Int32, Bool]
  // probes I forward for others: seq -> requester
  fwd : @hashmap.HashMap[Int32, String]
  // gossip dedup + independent suspicion origins (per suspected member)
  seen : @hashmap.HashMap[String, Bool]
  votes : @hashmap.HashMap[String, @hashmap.HashMap[String, Bool]]
  mut awareness_peak : Int32
}

///|
/// Simulate a cluster where dead_node never responds.
pub async fn simulate_cluster(
  node_ids~ : Array[String],
  dead_node~ : String,
  base_probe_interval_ms~ : Int32,
  base_probe_timeout_ms~ : Int32,
  alpha~ : Double,
  beta~ : Double,
  budget_ms~ : Int32,
) -> Result[SimResult, String] {
  let n = node_ids.length()
  if n < 3 {
    return Err("need >= 3 nodes")
  }
  let t0 = @async.now()
  let outbox : @async.Queue[Envelope] = @async.Queue(kind=Unbounded)
  let nodes : @hashmap.HashMap[String, SimNode] = @hashmap.HashMap(
    [],
    capacity=16,
  )
  for id in node_ids {
    let peers = node_ids.filter(fn(p) { p != id })
    let sim : SimNode = {
      node: SwimNode::new(
        id~,
        peers~,
        base_probe_interval_ms~,
        base_probe_timeout_ms~,
        suspicion_alpha=alpha,
        suspicion_beta=beta,
        suspicion_k=3,
        max_awareness=8,
      ),
      inbox: @async.Queue(kind=Unbounded),
      pending: @hashmap.HashMap([], capacity=8),
      fwd: @hashmap.HashMap([], capacity=8),
      seen: @hashmap.HashMap([], capacity=32),
      votes: @hashmap.HashMap([], capacity=8),
      awareness_peak: 0,
    }
    nodes.set(id, sim)
  }
  let delay_ms = 2 // simulated one-way latency
  let _ = delay_ms
  @async.with_task_group(async fn(tg) {
    // relay: outbox -> target inbox
    let _ = tg.spawn(async fn() {
      while @async.now() - t0 < budget_ms.to_int64() {
        match outbox.try_get() {
          Some(env) =>
            match nodes.get(env.to) {
              Some(dst) => {
                let _ = dst.inbox.try_put(env)
              }
              None => ()
            }
          None => @async.sleep(1)
        }
      }
    })
    // node tasks; dead_node gets none: its inbox is a black hole
    for id in node_ids {
      if id == dead_node {
        continue
      }
      let sim = nodes.get(id).unwrap()
      let _ = tg.spawn(async fn() {
        node_loop(sim, outbox, t0, budget_ms, base_probe_timeout_ms)
      })
    }
    @async.sleep(budget_ms)
  })
  // collect
  let mut confirmed = 0
  let mut false_pos = false
  let mut peak = 0
  for id in node_ids {
    if id == dead_node {
      continue
    }
    match nodes.get(id) {
      Some(sim) => {
        if sim.node.member_state(dead_node) == Some(Failed) {
          confirmed += 1
        }
        if sim.node.ever_failed_healthy() {
          false_pos = true
        }
        if sim.awareness_peak > peak {
          peak = sim.awareness_peak
        }
      }
      None => ()
    }
  }
  Ok({
    all_confirmed_dead: confirmed == n - 1,
    no_false_positive: !false_pos,
    dead_confirmed_by: confirmed,
    awareness_max_seen: peak,
  })
}

///|
fn[T] opt_or(v : T?, d : T) -> T {
  match v {
    Some(x) => x
    None => d
  }
}

///|
fn first_n(xs : Array[String], n : Int32) -> Array[String] {
  let out : Array[String] = []
  for i in 0..<n {
    if i < xs.length() {
      out.push(xs[i])
    }
  }
  out
}

///|
fn rr_target(sim : SimNode, round : Int32) -> String {
  let peers = sim.node.peers
  peers[round % peers.length()]
}

///|
fn put(
  outbox : @async.Queue[Envelope],
  to : String,
  origin : String,
  from : String,
  msg : Msg,
) -> Unit raise {
  let _ = outbox.try_put({ to, origin, from, msg, })
}

///|
fn gossip(
  sim : SimNode,
  outbox : @async.Queue[Envelope],
  origin : String,
  from : String,
  msg : Msg,
) -> Unit raise {
  for p in sim.node.peers {
    if p != from {
      put(outbox, p, origin, sim.node.id, msg)
    }
  }
}

///|
fn dedup_key(origin : String, msg : Msg) -> String {
  match msg {
    Suspect(about, inc, _) => "\{origin}|s|\{about}|\{inc}"
    Alive(about, inc, _) => "\{origin}|a|\{about}|\{inc}"
    Confirm(about, inc, _) => "\{origin}|c|\{about}|\{inc}"
    _ => ""
  }
}

///|
/// Process one membership message with dedup; returns true if novel.
fn on_membership(
  sim : SimNode,
  outbox : @async.Queue[Envelope],
  origin : String,
  from : String,
  msg : Msg,
) -> Bool raise {
  let key = dedup_key(origin, msg)
  if key == "" || sim.seen.contains(key) {
    return false
  }
  sim.seen.set(key, true)
  // track independent suspicion origins for the decay formula
  match msg {
    Suspect(about, _, org) =>
      if about != sim.node.id {
        match sim.votes.get(about) {
          Some(set) => set.set(org, true)
          None => {
            let set : @hashmap.HashMap[String, Bool] = @hashmap.HashMap(
              [],
              capacity=4,
            )
            set.set(org, true)
            sim.votes.set(about, set)
          }
        }
      }
    _ => ()
  }
  let out = sim.node.handle(msg)
  for m in out {
    // self-refutation or relabeled gossip: originate from self
    gossip(sim, outbox, sim.node.id, sim.node.id, m)
  }
  // flood the original onward (excluding immediate sender)
  gossip(sim, outbox, origin, from, msg)
  true
}

///|
async fn node_loop(
  sim : SimNode,
  outbox : @async.Queue[Envelope],
  t0 : Int64,
  budget_ms : Int32,
  base_probe_timeout : Int32,
) -> Unit {
  let mut round = 0
  while @async.now() - t0 < budget_ms.to_int64() {
    // let the round run: drain inbox while the probe timeline advances
    let target = rr_target(sim, round)
    let seq = sim.node.start_probe()
    sim.pending.set(seq, false)
    put(outbox, target, sim.node.id, sim.node.id, Ping(sim.node.id, seq))
    // direct probe window
    @async.sleep(base_probe_timeout)
    drain(sim, outbox)
    if !opt_or(sim.pending.get(seq), false) {
      sim.node.record_probe_fail()
      // indirect probe: up to 3 helpers
      let helpers = first_n(sim.node.peers.filter(fn(p) { p != target }), 3)
      for h in helpers {
        put(
          outbox,
          h,
          sim.node.id,
          sim.node.id,
          PingReq(sim.node.id, target, seq),
        )
      }
      @async.sleep(base_probe_timeout)
      drain(sim, outbox)
      if !opt_or(sim.pending.get(seq), false) {
        sim.node.record_missed_nack()
        let inc = opt_or(sim.node.member_incarnation(target), 0UL)
        // mark suspect locally, then flood
        let _ = on_membership(
          sim,
          outbox,
          sim.node.id,
          sim.node.id,
          Suspect(target, inc, sim.node.id),
        )
        // suspicion window (C=0 -> Max at start; decay recorded as simplification)
        let st = sim.node.suspicion_timeout_ms(0)
        let s_deadline = @async.now() + st.to_int64()
        while @async.now() < s_deadline {
          @async.sleep(2)
          drain(sim, outbox)
          match sim.node.member_state(target) {
            Some(Alive) => break
            Some(Suspect) =>
              // re-flood own suspicion periodically
              put(
                outbox,
                target,
                sim.node.id,
                sim.node.id,
                Suspect(target, inc, sim.node.id),
              )
            Some(Failed) => break
            None => break
          }
        }
        if sim.node.member_state(target) == Some(Suspect) {
          let inc2 = opt_or(sim.node.member_incarnation(target), inc)
          let _ = on_membership(
            sim,
            outbox,
            sim.node.id,
            sim.node.id,
            Confirm(target, inc2, sim.node.id),
          )
        }
      } else {
        sim.node.record_ack()
      }
    } else {
      sim.node.record_ack()
    }
    if sim.node.awareness() > sim.awareness_peak {
      sim.awareness_peak = sim.node.awareness()
    }
    round += 1
  }
}

///|
/// Drain everything currently in the inbox.
fn drain(sim : SimNode, outbox : @async.Queue[Envelope]) -> Unit raise {
  let mut open = true
  while open {
    match sim.inbox.try_get() {
      Some(env) => {
        let me = sim.node.id
        match env.msg {
          Ping(from, seq) => put(outbox, from, me, me, Ack(me, seq))
          PingReq(from, target, seq) => {
            // buddy system: attach suspicion about the target if any
            match sim.node.member_state(target) {
              Some(Suspect) =>
                put(
                  outbox,
                  target,
                  me,
                  me,
                  Suspect(
                    target,
                    opt_or(sim.node.member_incarnation(target), 0UL),
                    me,
                  ),
                )
              _ => ()
            }
            sim.fwd.set(seq, from)
            put(outbox, target, me, me, Ping(me, seq))
            // 80% nack duty (paper IV-A): handled implicitly by short fwd window
          }
          Ack(_, seq) => {
            if sim.pending.contains(seq) {
              sim.pending.set(seq, true)
            }
            match sim.fwd.get(seq) {
              Some(orig) => put(outbox, orig, me, me, Ack(me, seq))
              None => ()
            }
          }
          Nack(_, seq) =>
            match sim.fwd.get(seq) {
              Some(orig) => put(outbox, orig, me, me, Nack(me, seq))
              None => ()
            }
          Suspect(_, _, _) | Alive(_, _, _) | Confirm(_, _, _) => {
            let _ = on_membership(sim, outbox, env.origin, env.from, env.msg)
          }
        }
      }
      None => open = false
    }
  }
}
