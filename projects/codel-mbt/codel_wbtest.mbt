// Paper-criterion tests: CoDel (Nichols, Jacobson et al., RFC 8289).
// All deterministic — the network is a discrete-event stub (this round's
// theme: the systems-paper degraded route).

///|
test "control law matches the sqrt servo schedule (T-CTRL-LAW)" {
  // §5.6: drop_next = t + INTERVAL / sqrt(count)
  let t = 0
  assert_eq(control_law(t, 1), 100000) // INTERVAL / sqrt(1) = 100 ms
  assert_eq(control_law(t, 4), 50000) // 100 / 2 = 50 ms
  assert_eq(control_law(t, 100), 10000) // 100 / 10 = 10 ms
  // exact sqrt values keep equality; non-exact values ceil upward
  assert_eq(control_law(t, 2), 70711) // 100/sqrt(2) = 70.71 ms -> ceil
  // nonnegativity floor
  assert_eq(control_law(123456, 999999) > 123456, true)
}

///|
test "dodequeue tracks first_above_time and resets (T-DODEQUEUE)" {
  // §5.6 helper: first above arms the timer (first_above_time = now+INTERVAL);
  // ok_to_drop only fires on a LATER dequeue past the armed time; bytes() <=
  // maxpacket or sojourn < TARGET resets.
  let q = CodelQueue::new()
  // below TARGET: sojourn 1 ms
  q.enqueue(1500, 0)
  let r1 = q.dodequeue(1000)
  assert_eq(r1.ok_to_drop, false)
  assert_eq(q.first_above_time(), 0)
  // sustained congestion: 4 stale packets; dequeue one leaves 3*1500 bytes
  for _ in 0..<4 {
    q.enqueue(1500, 0)
  }
  let r2 = q.dodequeue(20000) // sojourn 20 ms >= 5 ms; first above -> arm
  assert_eq(r2.ok_to_drop, false) // arming call does NOT drop
  assert_eq(q.first_above_time(), 20000 + 100000)
  // still above past the armed time -> ok_to_drop
  let r3 = q.dodequeue(120001)
  assert_eq(r3.ok_to_drop, true)
}

///|
test "empty dequeue resets first_above_time (T-DODEQUEUE empty)" {
  // §5.6: queue empty -> "we can't be above TARGET" -> reset
  let q = CodelQueue::new()
  for _ in 0..<3 {
    q.enqueue(1500, 0)
  }
  let _ = q.dodequeue(20000) // arms first_above_time
  assert_eq(q.first_above_time() != 0, true)
  // drain the queue, then dequeue from empty: reset fires
  while q.queue_len() > 0 {
    let _ = q.dodequeue(30000)
  }
  let r = q.dodequeue(30000)
  assert_eq(r.ok_to_drop, false)
  assert_eq(q.first_above_time(), 0)
}

///|
test "dequeue drop sequence follows control law (T-DROP-SEQ)" {
  // sustained congestion: stale packets keep sojourn >= TARGET.
  // First dequeue arms, second (past the armed time) drops and enters
  // dropping state; subsequent drop times chain through control_law.
  let q = CodelQueue::new()
  for _ in 0..<30 {
    q.enqueue(1500, 0)
  }
  let mut now = 200000
  let _ = q.dequeue(now) // arming call (no drop yet)
  assert_eq(q.dropping(), false)
  assert_eq(q.count(), 0)
  now = q.first_above_time() // exactly the armed instant
  let _ = q.dequeue(now) // ok_to_drop -> drop + enter dropping
  assert_eq(q.dropping(), true)
  assert_eq(q.count() == 1, true)
  let drop_times : Array[Int32] = [q.drop_next()]
  // keep dequeuing at the scheduled drop times; while-loop drops fire and
  // each schedule step must equal ceil(INTERVAL/sqrt(count))
  let mut k = 0
  while k < 8 {
    now = q.drop_next()
    let _ = q.dequeue(now)
    drop_times.push(q.drop_next())
    k += 1
  }
  for i in 0..<8 {
    let gap = drop_times[i + 1] - drop_times[i]
    let expect = control_law(0, i + 2)
    assert_eq(gap == expect, true)
  }
}

///|
test "leaving dropping state resets and Linux count inherits (T-LINUX-COUNT)" {
  // §5.5 Linux variant: after leaving drop state, if the queue goes above
  // TARGET again within 16*INTERVAL and delta > 1, count_ = delta.
  let q = CodelQueue::new()
  for _ in 0..<10 {
    q.enqueue(1500, 0)
  }
  let _ = q.dequeue(200000) // arm
  let _ = q.dequeue(300000) // ok -> enter dropping, count=1
  assert_eq(q.dropping(), true)
  // keep the drop loop running to raise count
  let _ = q.dequeue(400000) // scheduled drop fires, count=2
  assert_eq(q.count() == 2, true)
  // congestion clears: enqueue fresh packets, dequeue so sojourn < TARGET
  q.enqueue(1500, 480000)
  let _ = q.dequeue(481000) // sojourn 1 ms < 5 ms -> leave drop state
  assert_eq(q.dropping(), false)
  let high_count = q.count()
  assert_eq(high_count >= 2, true)
  // rapid re-entry: stale packets again within 16*INTERVAL of drop_next
  for _ in 0..<5 {
    q.enqueue(1500, 481000)
  }
  let _ = q.dequeue(481000 + 100000) // arm past TARGET (stale stamps)
  let _ = q.dequeue(481000 + 200000) // ok -> re-enter dropping
  assert_eq(q.dropping(), true)
  // Linux count inheritance: re-entered count should be >= 2 (delta carried)
  assert_eq(q.count() >= 2, true)
}

///|
test "servo loop keeps sojourn under TARGET with high utilization (T-SERVIO)" {
  // §4.1-4.2 design claim: CoDel is a closed-loop servo — with a TCP-like
  // AIMD sender over a deterministic discrete-event network, the steady-state
  // local minimum sojourn time stays <= TARGET while link utilization
  // stays high (no idle-starving).
  let sim = NetSim::new(send_time=1000, rtt=10000)
  let result = sim.run(duration=2000000) // 2 s simulated
  // local minimum sojourn time in the steady state (last 50% of the run)
  assert_eq(result.min_sojourn_steady() <= 5000, true)
  // utilization: the link sent packets for >= 50% of the window
  assert_eq(result.utilization_steady() >= 0.5, true)
  // the servo actually acted: at least one drop occurred
  assert_eq(result.drops() >= 1, true)
}
