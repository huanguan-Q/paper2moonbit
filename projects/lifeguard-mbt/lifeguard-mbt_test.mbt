///|
// Blackbox spec tests — paper criteria from arXiv:1707.00788v2.

fn mk_node() -> @lifeguard.SwimNode {
  @lifeguard.SwimNode::new(
    id="n1",
    peers=["n2", "n3", "n4", "n5"],
    base_probe_interval_ms=1000,
    base_probe_timeout_ms=500,
    suspicion_alpha=5.0,
    suspicion_beta=6.0,
    suspicion_k=3,
    max_awareness=8,
  )
}

///|
test "awareness saturates at [0, S]" {
  let n = mk_node()
  // probe failures increase 1-by-1 up to S=8, never beyond
  for i in 0..<7 {
    n.record_probe_fail()
    assert_eq(n.awareness(), i + 1)
  }
  n.record_probe_fail()
  n.record_probe_fail()
  assert_eq(n.awareness(), 8) // saturated
  // acks decrease, never below 0
  for _ in 0..<10 {
    n.record_ack()
  }
  assert_eq(n.awareness(), 0)
}

///|
test "probe backoff scales with LHM+1" {
  let n = mk_node()
  assert_eq(n.probe_interval_ms(), 1000) // a=0
  assert_eq(n.probe_timeout_ms(), 500)
  n.record_probe_fail()
  assert_eq(n.probe_interval_ms(), 2000)
  // saturate awareness to 8 -> 9x backoff
  for _ in 0..<7 {
    n.record_probe_fail()
  }
  assert_eq(n.probe_interval_ms(), 9000)
  assert_eq(n.probe_timeout_ms(), 4500)
}

///|
test "suspicion timeout: log decay toward Min as independent suspects arrive" {
  let n = mk_node()
  // n = 5 members: Min = 5 * log10(5) * 1000 = 3494.85 -> 3494
  let min = n.suspicion_min_ms()
  assert_eq(min, 3494)
  let max = 6 * min
  // C=0 (just suspected locally): timeout = Max
  assert_eq(n.suspicion_timeout_ms(0), max)
  // C=1: ln(2)/ln(4) = 0.5 -> midpoint
  assert_eq(n.suspicion_timeout_ms(1), max - (max - min) / 2)
  // C=K=3: fully decayed to Min
  assert_eq(n.suspicion_timeout_ms(3), min)
}

///|
test "SWIM: suspect marks member, only higher-incarnation alive refutes" {
  let n = mk_node()
  let _ = n.handle(@lifeguard.Suspect("n2", 0UL, "n3"))
  assert_eq(n.member_state("n2"), Some(@lifeguard.Suspect))
  // equal-incarnation alive does NOT refute
  let _ = n.handle(@lifeguard.Alive("n2", 0UL, "n2"))
  assert_eq(n.member_state("n2"), Some(@lifeguard.Suspect))
  // higher incarnation refutes -> Alive
  let _ = n.handle(@lifeguard.Alive("n2", 1UL, "n2"))
  assert_eq(n.member_state("n2"), Some(@lifeguard.Alive))
  assert_eq(n.member_incarnation("n2"), Some(1UL))
}

///|
test "SWIM: confirm is terminal" {
  let n = mk_node()
  let _ = n.handle(@lifeguard.Suspect("n2", 0UL, "n3"))
  let _ = n.handle(@lifeguard.Confirm("n2", 0UL, "n4"))
  assert_eq(n.member_state("n2"), Some(@lifeguard.Failed))
  // even a much higher incarnation cannot resurrect a confirmed node
  let _ = n.handle(@lifeguard.Alive("n2", 5UL, "n2"))
  assert_eq(n.member_state("n2"), Some(@lifeguard.Failed))
  // n2 went through Suspect first: legitimate confirmation, not a false positive
  assert_eq(n.ever_failed_healthy(), false)
  // but confirming a node that was never suspected IS a false positive
  let _ = n.handle(@lifeguard.Confirm("n3", 0UL, "n4"))
  assert_eq(n.ever_failed_healthy(), true)
}

///|
test "SWIM: a node refutes suspicion about itself" {
  let n = mk_node()
  let out = n.handle(@lifeguard.Suspect("n1", 0UL, "n3"))
  // n1 refutes: emits Alive(n1, inc+1)
  let refute = out.filter(
    fn(m) {
      match m {
        @lifeguard.Alive("n1", inc, "n1") => inc == 1UL
        _ => false
      }
    },
  )
  assert_eq(refute.length(), 1)
  assert_eq(n.self_incarnation(), 1UL)
  // refuting costs +1 awareness
  assert_eq(n.awareness(), 1)
}

///|
// Integration: async simulation of a 5-node cluster; n5 dies.
async test "lifeguard integration: dead node confirmed, healthy nodes unaffected" {
  let result = @lifeguard.simulate_cluster(
    node_ids=["n1", "n2", "n3", "n4", "n5"],
    dead_node="n5",
    base_probe_interval_ms=30,
    base_probe_timeout_ms=20,
    alpha=5.0,
    beta=6.0,
    budget_ms=5000,
  )
  match result {
    Ok(r) => {
      assert_eq(r.all_confirmed_dead, true)
      assert_eq(r.dead_confirmed_by, 4)
      assert_eq(r.no_false_positive, true)
    }
    Err(msg) => abort("simulation failed: \{msg}")
  }
}
