///|
// Paper-criteria tests (Shapiro et al. 2011, INRIA RR-7687), blackbox via @crdt.
// Each test cites its source specification.

///|
// Spec 6: value() = Σ P[i]
test "G-Counter: value is sum of per-replica entries (Spec 6)" {
  let c = @crdt.GCounter::new(4)
  c.increment(0)
  c.increment(0)
  c.increment(1)
  assert_eq(c.value(), 3)
  assert_eq(c.leq(c), true)
}

///|
// Spec 6: merge is per-entry max → idempotent and commutative (semilattice LUB)
test "G-Counter: merge idempotent and commutative (Spec 6)" {
  let a = @crdt.GCounter::new(4)
  let b = @crdt.GCounter::new(4)
  a.increment(0)
  a.increment(1)
  b.increment(1)
  b.increment(2)
  a.merge(b)
  assert_eq(a.value(), 3)
  a.merge(b) // idempotent: second merge changes nothing
  assert_eq(a.value(), 3)
  b.merge(a) // commutative: reverse order reaches same state
  assert_eq(b.value(), 3)
}

///|
// §3.1.2: n replicas each originating k increments converge to n·k
test "G-Counter: 4 replicas x 5 increments converge to 20 (paper criteria)" {
  let k = 5
  let reps : Array[@crdt.GCounter] = []
  for i in 0..<4 {
    let r = @crdt.GCounter::new(4)
    for _ in 0..<k {
      r.increment(i)
    }
    reps.push(r)
  }
  // arbitrary pairwise merges, then read from any replica
  reps[0].merge(reps[2])
  reps[3].merge(reps[1])
  reps[2].merge(reps[3])
  assert_eq(reps[2].value(), 15) // [0,5,5,5]: absorbed replicas 1 and 3, not 0
  reps[0].merge(reps[1])
  reps[0].merge(reps[2])
  assert_eq(reps[0].value(), 20)
}

///|
// Spec 7: value() = ΣP − ΣN; supports decrement, may go negative
test "PN-Counter: value = increments - decrements (Spec 7)" {
  let c = @crdt.PNCounter::new(4)
  c.increment(0)
  c.increment(1)
  c.decrement(2)
  assert_eq(c.value(), 1)
  c.decrement(3)
  c.decrement(3)
  assert_eq(c.value(), -1)
  c.merge(c) // idempotent merge (conjunction of G-Counter merges)
  assert_eq(c.value(), -1)
}

///|
// Spec 8: merge selects the state with the maximal timestamp
test "LWW-Register: higher timestamp wins on merge (Spec 8)" {
  let r1 = @crdt.LWWReg::new()
  let r2 = @crdt.LWWReg::new()
  r1.assign(10, 5)
  r2.assign(20, 7)
  r1.merge(r2)
  assert_eq(r1.value(), 20)
  // reverse direction reaches the same winner
  let s1 = @crdt.LWWReg::new()
  let s2 = @crdt.LWWReg::new()
  s1.assign(10, 5)
  s2.assign(20, 7)
  s2.merge(s1)
  assert_eq(s2.value(), 20)
}

///|
// Spec 11: grow-only set, merge = union
test "G-Set: add-only union across replicas (Spec 11)" {
  let a = @crdt.GSet::new()
  let b = @crdt.GSet::new()
  a.add("x")
  b.add("y")
  a.merge(b)
  assert_eq(a.lookup("x"), true)
  assert_eq(a.lookup("y"), true)
  assert_eq(a.lookup("z"), false)
  b.merge(a)
  assert_eq(b.lookup("x"), true)
}

///|
// Spec 12: tombstone is permanent — a removed element never re-appears
test "2P-Set: removed element cannot re-appear via re-add (Spec 12)" {
  let s = @crdt.TwoPSet::new()
  s.add("a")
  assert_eq(s.lookup("a"), true)
  s.remove("a")
  assert_eq(s.lookup("a"), false)
  s.add("a") // add has no precondition, but lookup stays false: e ∈ R
  assert_eq(s.lookup("a"), false)
}

///|
// Spec 12: remove carries the source precondition lookup(e)
test "2P-Set: remove of absent element is rejected (Spec 12 pre)" {
  let s = @crdt.TwoPSet::new()
  assert_eq(s.can_remove("a"), false)
  s.add("a")
  assert_eq(s.can_remove("a"), true)
}

///|
// Figure 14: concurrent add(e) wins over remove(e) — the concurrent add's
// unique tag was never observed by the remove, so it survives the merge.
test "OR-Set: concurrent add wins over remove (Figure 14)" {
  let r1 = @crdt.ORSet::new(0) // tag space of replica 1
  let r2 = @crdt.ORSet::new(1) // tag space of replica 2
  r1.add("a") // tag α
  r2.merge(r1) // r2 has observed (a, α)
  r2.add("a") // tag β — concurrent with the coming remove
  r1.remove("a") // tombstones only the observed (a, α)
  assert_eq(r1.lookup("a"), false)
  // full sync both directions
  r1.merge(r2)
  r2.merge(r1)
  assert_eq(r1.lookup("a"), true) // (a, β) survives
  assert_eq(r2.lookup("a"), true)
}

///|
// §3.3.5: remove clears every observed tag; a later add gets a fresh tag
test "OR-Set: remove then re-add takes effect (unlike 2P-Set)" {
  let r = @crdt.ORSet::new(0)
  r.add("a")
  r.add("a") // two distinct tags
  r.remove("a") // tombstones both observed tags
  assert_eq(r.lookup("a"), false)
  r.add("a") // fresh tag ∉ tombstones
  assert_eq(r.lookup("a"), true)
}

///|
// §3.3.5: remove only affects tags observed at the source replica
test "OR-Set: remove is scoped to locally observed tags" {
  let r1 = @crdt.ORSet::new(0)
  let r2 = @crdt.ORSet::new(1)
  r1.add("a") // α at r1
  r1.add("a") // α' at r1
  r2.merge(r1)
  r2.remove("a") // r2 observed both tags
  assert_eq(r2.lookup("a"), false)
  r1.merge(r2) // r1's live pairs are covered by r2's tombstones
  assert_eq(r1.lookup("a"), false)
}
