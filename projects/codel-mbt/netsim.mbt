// Deterministic discrete-event network simulator — the environment stub
// for the systems-paper degraded route (same recipe as RQGM's LLM stubs):
// a sender with TCP-like AIMD behavior, a bottleneck link, and CoDel in
// the middle. No randomness: the sender's additive growth is a fixed
// increment per RTT, multiplicative decrease on every observed drop.

///|
pub struct SimResult {
  sojourn_min_log : Array[(Int32, Int32)] // (time, local min sojourn) samples
  sent_total : Int32
  drops : Int32
  duration : Int32
  steady_start : Int32
}

///|
pub struct NetSim {
  send_time : Int32 // link service time per packet (us)
  rtt : Int32 // sender RTT estimate (us)
  codel : CodelQueue
  // sender state (AIMD stub)
  priv mut rate : Double // packets offered per RTT
  priv mut last_rtt_check : Int32
}

///|
pub fn NetSim::new(send_time~ : Int32, rtt~ : Int32) -> NetSim {
  { send_time, rtt, codel: CodelQueue::new(), rate: 4.0, last_rtt_check: 0, }
}

///|
/// Run the simulation for `duration` microseconds from t=0.
pub fn NetSim::run(self : NetSim, duration~ : Int32) -> SimResult {
  let mut t = 0
  let mut link_free_at = 0
  let mut sent = 0
  let mut drops = 0
  let sojourn_log : Array[(Int32, Int32)] = []
  // event loop: at each link-free instant, offer packets at the AIMD rate
  // and run CoDel's dequeue; arrivals are batched per link-free slot
  // (deterministic, no randomness).
  while t <= duration {
    // sender side: every RTT, additive increase of the offered rate
    if t - self.last_rtt_check >= self.rtt {
      self.last_rtt_check = t
      self.rate += 1.0
    }
    // arrivals: enqueue floor(rate / 2) packets this slot (offered load)
    let arrivals = (self.rate / 2.0).floor().to_int()
    let mut a = 0
    while a < arrivals {
      self.codel.enqueue(1500, t)
      a += 1
    }
    // link service: dequeue one packet per send_time slot
    while link_free_at <= t {
      let out = self.codel.dequeue(t)
      match out {
        Some(_) => {
          sent += 1
          link_free_at = t + self.send_time
        }
        None => link_free_at = t + self.send_time // idle slot
      }
      // track sojourn of the packet just served (0 if empty/idle)
      // sampled via the queue's implicit head: measure enqueue timestamp
      // before dequeue by peeking — instead record drops and queue depth.
      // Sojourn tracking happens through the drop bookkeeping below.
      break
    }
    if self.codel.dropping() {
      drops += 1 // one slot of drop state counts the active drops
      // AIMD multiplicative decrease on observed dropping
      self.rate = self.rate / 2.0
      if self.rate < 1.0 {
        self.rate = 1.0
      }
    }
    // sample sojourn: current queue depth * send_time is the standing
    // sojourn estimate (packets in queue each wait send_time on average)
    let depth = self.codel.bytes() / 1500
    sojourn_log.push((t, depth * self.send_time))
    t += self.send_time
  }
  {
    sojourn_min_log: sojourn_log,
    sent_total: sent,
    drops,
    duration,
    steady_start: duration / 2,
  }
}

///|
/// Local minimum sojourn in the steady-state window (last half of the run).
pub fn SimResult::min_sojourn_steady(self : SimResult) -> Int32 {
  let mut mn = 2147483647
  for kv in self.sojourn_min_log {
    let (t, v) = kv
    if t >= self.steady_start && v < mn {
      mn = v
    }
  }
  mn
}

///|
/// Link utilization in the steady-state window: fraction of sampled slots
/// where the queue had packets waiting (proxy for the link being busy).
pub fn SimResult::utilization_steady(self : SimResult) -> Double {
  let mut busy = 0
  let mut total = 0
  for kv in self.sojourn_min_log {
    let (t, v) = kv
    if t >= self.steady_start {
      total += 1
      if v > 0 {
        busy += 1
      }
    }
  }
  if total == 0 {
    0.0
  } else {
    busy.to_double() / total.to_double()
  }
}

///|
pub fn SimResult::drops(self : SimResult) -> Int32 {
  self.drops
}
