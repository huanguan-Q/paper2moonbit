// CoDel control law and queue — RFC 8289 §5.4-5.6 pseudocode line by line.
// time domain: Int microseconds (RFC §5.7 allows integer time at >= ms
// resolution; finer is permitted up to the minimum packet time).

///|
const TARGET_US : Int32 = 5000 // 5 ms TARGET queue delay (§5.4)

///|
const INTERVAL_US : Int32 = 100000 // 100 ms sliding-minimum window (§5.4)

///|
const MAXPACKET : Int32 = 1500 // MTU-sized packet bytes

///|
/// §5.6 control law: drop_next = t + INTERVAL / sqrt(count). The sqrt
/// dependence mirrors TCP throughput ~ sqrt(p). Integer-ceil domain
/// (Linux implementation does the same integer reduction).
pub fn control_law(t : Int32, count : Int32) -> Int32 {
  let step = (INTERVAL_US.to_double() / @math.pow(count.to_double(), 0.5))
    .ceil()
    .to_int()
  t + step
}

///|
/// A packet carries only its enqueue timestamp (RFC §5.4 tstamp field).
pub struct Packet {
  tstamp : Int32
  size : Int32
}

///|
pub struct DodequeueResult {
  p : Packet? // None when the queue was empty or the packet was dropped
  ok_to_drop : Bool
}

///|
/// CoDel queue state (§5.4 + §5.5): all state lives on the dequeue side.
pub struct CodelQueue {
  priv packets : Array[Packet] // FIFO, head at index 0
  priv mut dropping : Bool
  priv mut count : Int32
  priv mut lastcount : Int32
  priv mut drop_next : Int32
  priv mut first_above_time : Int32
}

///|
pub fn CodelQueue::new() -> CodelQueue {
  {
    packets: [],
    dropping: false,
    count: 0,
    lastcount: 0,
    drop_next: 0,
    first_above_time: 0,
  }
}

///|
/// §5.4 enqueue: stamp the packet; a full buffer drops the incoming packet
/// (we model no upper bound here — the simulator never overflows).
pub fn CodelQueue::enqueue(
  self : CodelQueue,
  size : Int32,
  now : Int32,
) -> Unit {
  self.packets.push({ tstamp: now, size, })
}

///|
pub fn CodelQueue::bytes(self : CodelQueue) -> Int32 {
  let mut acc = 0
  for p in self.packets {
    acc += p.size
  }
  acc
}

///|
pub fn CodelQueue::first_above_time(self : CodelQueue) -> Int32 {
  self.first_above_time
}

///|
pub fn CodelQueue::dropping(self : CodelQueue) -> Bool {
  self.dropping
}

///|
pub fn CodelQueue::count(self : CodelQueue) -> Int32 {
  self.count
}

///|
pub fn CodelQueue::drop_next(self : CodelQueue) -> Int32 {
  self.drop_next
}

///|
/// §5.6 helper: dequeue one packet and track whether sojourn time has been
/// above TARGET continuously for INTERVAL. Returns the packet (None on
/// empty or drop) plus the ok_to_drop flag.
pub fn CodelQueue::dodequeue(self : CodelQueue, now : Int32) -> DodequeueResult {
  if self.packets.length() == 0 {
    // queue is empty - we can't be above TARGET
    self.first_above_time = 0
    return { p: None, ok_to_drop: false, }
  }
  let p = self.packets.remove(0)
  let sojourn_time = now - p.tstamp
  if sojourn_time < TARGET_US || self.bytes() <= MAXPACKET {
    // went below - stay below for at least INTERVAL
    self.first_above_time = 0
    { p: Some(p), ok_to_drop: false, }
  } else if self.first_above_time == 0 {
    // just went above from below: arm the declaration timer
    self.first_above_time = now + INTERVAL_US
    { p: Some(p), ok_to_drop: false, }
  } else if now >= self.first_above_time {
    { p: Some(p), ok_to_drop: true, }
  } else {
    { p: Some(p), ok_to_drop: false, }
  }
}

///|
/// Internal: drop the head packet, returning it as a dropped marker
/// (packet value 0 in the test observation).
fn CodelQueue::drop_head(self : CodelQueue) -> Packet? {
  if self.packets.length() == 0 {
    None
  } else {
    Some(self.packets.remove(0))
  }
}

///|
/// §5.5 dequeue routine verbatim: the entire CoDel control action happens
/// here. Returns the delivered packet, or None when the packet was dropped
/// (observed as 0 in tests).
pub fn CodelQueue::dequeue(self : CodelQueue, now : Int32) -> Packet? {
  let mut r = self.dodequeue(now)
  if self.dropping {
    if !r.ok_to_drop {
      // sojourn time below TARGET - leave drop state
      self.dropping = false
    }
    // time for the next scheduled drop; a large backlog may make the next
    // drop due right now, hence the while loop
    while now >= self.drop_next && self.dropping {
      let _ = self.drop_head()
      self.count += 1
      r = self.dodequeue(now)
      if !r.ok_to_drop {
        // leave drop state
        self.dropping = false
      } else {
        // schedule the next drop
        self.drop_next = control_law(self.drop_next, self.count)
      }
    }
  } else if r.ok_to_drop {
    // sojourn has been above TARGET for INTERVAL: enter drop state
    let _ = self.drop_head()
    r = self.dodequeue(now)
    self.dropping = true
    // Linux variant: reuse the previous cycle's drop rate if we re-entered
    // quickly (delta > 1 and within 16*INTERVAL of the last drop time)
    let delta = self.count - self.lastcount
    self.count = 1
    if delta > 1 && now - self.drop_next < 16 * INTERVAL_US {
      self.count = delta
    }
    self.drop_next = control_law(now, self.count)
    self.lastcount = self.count
  }
  r.p
}

///|
/// Current packet count (test observation helper).
pub fn CodelQueue::queue_len(self : CodelQueue) -> Int32 {
  self.packets.length()
}
