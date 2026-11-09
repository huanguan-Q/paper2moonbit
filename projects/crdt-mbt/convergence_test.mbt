///|
// Convergence PBT (paper Definition 2.3, Eventual Convergence): after random
// op streams and arbitrary pairwise merges, a full bidirectional sync must
// bring every replica to an equivalent abstract state, and two different
// merge orders must produce the same result. Deterministic seeds.

///|
// Lehmer/LCG PRNG via Int64 — no 32-bit overflow, deterministic.
fn next_rand(state : Int64) -> Int64 {
  state * 48271L % 2147483647L
}

///|
// Track the analytically expected counter value while applying random ops:
// every increment is +1 and every decrement is -1 regardless of merge order,
// so after full sync every replica must equal the expectation exactly.
test "PN-Counter: random stream converges to analytic value" {
  let mut seed = 42L
  let reps : Array[@crdt.PNCounter] = []
  for _ in 0..<4 {
    reps.push(@crdt.PNCounter::new(4))
  }
  let mut expected = 0
  for _ in 0..<200 {
    seed = next_rand(seed)
    let op = (seed % 3L).to_int()
    seed = next_rand(seed)
    let rep = (seed % 4L).to_int()
    if op == 0 {
      reps[rep].increment(rep)
      expected += 1
    } else if op == 1 {
      reps[rep].decrement(rep)
      expected -= 1
    } else {
      seed = next_rand(seed)
      let other = (seed % 4L).to_int()
      reps[rep].merge(reps[other])
    }
  }
  // star sync: all merge into 0, then 0 broadcasts back
  for i in 1..<4 {
    reps[0].merge(reps[i])
  }
  for i in 1..<4 {
    reps[i].merge(reps[0])
  }
  for i in 0..<4 {
    assert_eq(reps[i].value(), expected)
  }
  // two different merge orders give the same result
  let acc1 = @crdt.PNCounter::new(4)
  acc1.merge(reps[0])
  acc1.merge(reps[1])
  acc1.merge(reps[2])
  acc1.merge(reps[3])
  let acc2 = @crdt.PNCounter::new(4)
  acc2.merge(reps[3])
  acc2.merge(reps[2])
  acc2.merge(reps[1])
  acc2.merge(reps[0])
  assert_eq(acc1.value(), expected)
  assert_eq(acc2.value(), expected)
}

///|
// OR-Set convergence: after full sync every replica agrees on every lookup,
// regardless of interleaving (Def 2.3 "equivalent abstract state").
test "OR-Set: random add/remove/merge stream converges" {
  let elems = ["a", "b", "c"]
  let mut seed = 2024L
  let reps : Array[@crdt.ORSet] = []
  for i in 0..<3 {
    reps.push(@crdt.ORSet::new(i * 1_000_000))
  }
  for _ in 0..<200 {
    seed = next_rand(seed)
    let op = (seed % 3L).to_int()
    seed = next_rand(seed)
    let rep = (seed % 3L).to_int()
    seed = next_rand(seed)
    let e = elems[(seed % 3L).to_int()]
    if op == 0 {
      reps[rep].add(e)
    } else if op == 1 {
      reps[rep].remove(e) // removals of absent elements are no-ops
    } else {
      seed = next_rand(seed)
      let other = (seed % 3L).to_int()
      reps[rep].merge(reps[other])
    }
  }
  for i in 1..<3 {
    reps[0].merge(reps[i])
  }
  for i in 1..<3 {
    reps[i].merge(reps[0])
  }
  for e in elems {
    let v0 = reps[0].lookup(e)
    for i in 1..<3 {
      assert_eq(reps[i].lookup(e), v0)
    }
  }
  // different merge orders agree
  let acc1 = @crdt.ORSet::new(9_000_000)
  acc1.merge(reps[0])
  acc1.merge(reps[1])
  acc1.merge(reps[2])
  let acc2 = @crdt.ORSet::new(9_000_000)
  acc2.merge(reps[2])
  acc2.merge(reps[1])
  acc2.merge(reps[0])
  for e in elems {
    assert_eq(acc1.lookup(e), acc2.lookup(e))
  }
}

///|
// LWW-Register: globally increasing logical timestamps (consistent with
// causality, paper §3.2.1) — concurrent merge order must not change winner.
test "LWW-Register: random assigns converge to max-timestamp value" {
  let mut seed = 77L
  let reps : Array[@crdt.LWWReg] = []
  for _ in 0..<3 {
    reps.push(@crdt.LWWReg::new())
  }
  let mut ts = 0
  let mut best_ts = 0
  let mut best_val = 0
  for _ in 0..<100 {
    seed = next_rand(seed)
    let rep = (seed % 3L).to_int()
    ts += 1
    seed = next_rand(seed)
    let val = (seed % 1000L).to_int()
    reps[rep].assign(val, ts)
    if ts >= best_ts {
      best_ts = ts
      best_val = val
    }
    seed = next_rand(seed)
    if seed % 2L == 0L {
      seed = next_rand(seed)
      let other = (seed % 3L).to_int()
      reps[rep].merge(reps[other])
    }
  }
  for i in 1..<3 {
    reps[0].merge(reps[i])
    reps[i].merge(reps[0])
  }
  for i in 0..<3 {
    assert_eq(reps[i].value(), best_val)
  }
}

///|
// 2P-Set convergence: added-union + tombstone-union commute, so random
// streams must converge to the same membership on every replica.
test "2P-Set: random add/remove/merge stream converges" {
  let elems = ["a", "b", "c"]
  let mut seed = 555L
  let reps : Array[@crdt.TwoPSet] = []
  for _ in 0..<3 {
    reps.push(@crdt.TwoPSet::new())
  }
  for _ in 0..<150 {
    seed = next_rand(seed)
    let op = (seed % 3L).to_int()
    seed = next_rand(seed)
    let rep = (seed % 3L).to_int()
    seed = next_rand(seed)
    let e = elems[(seed % 3L).to_int()]
    if op == 0 {
      reps[rep].add(e)
    } else if op == 1 && reps[rep].can_remove(e) {
      reps[rep].remove(e)
    } else {
      seed = next_rand(seed)
      let other = (seed % 3L).to_int()
      reps[rep].merge(reps[other])
    }
  }
  for i in 1..<3 {
    reps[0].merge(reps[i])
  }
  for i in 1..<3 {
    reps[i].merge(reps[0])
  }
  for e in elems {
    let v0 = reps[0].lookup(e)
    for i in 1..<3 {
      assert_eq(reps[i].lookup(e), v0)
    }
  }
}
