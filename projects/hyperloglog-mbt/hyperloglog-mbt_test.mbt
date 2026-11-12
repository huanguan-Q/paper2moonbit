///|
// Blackbox: paper criteria (Flajolet et al., DMTCS 2007).

///|
fn splitmix64(state : UInt64) -> (UInt64, UInt64) {
  let z = state + 0x9E3779B97F4A7C15UL
  let mut x = z
  x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9UL
  x = (x ^ (x >> 27)) * 0x94D049BB133111EBUL
  x = x ^ (x >> 31)
  (z, x)
}

///|
test "empty sketch estimates 0" {
  let h = @hyperloglog.HLL::new(10)
  assert_eq(h.count() < 0.0001, true)
  assert_eq(h.num_registers(), 1024)
}

///|
test "idempotent adds: registers never decrease" {
  let h = @hyperloglog.HLL::new(8)
  let mut seed = 42UL
  let mut first = 0UL
  for i in 0..<100 {
    let (_, v) = splitmix64(seed)
    seed = v
    if i == 0 {
      first = v
    }
    h.add(v)
  }
  let c1 = h.count()
  // replaying an already-added element must not change any register
  h.add(first)
  h.add(first)
  let c2 = h.count()
  assert_eq(c2 == c1, true)
}

///|
test "small range: linear counting tracks true cardinality" {
  // m=1024; n up to 1000 is small range -> linear counting applies
  let seed = 7UL
  let mut n = 0
  while n < 1000 {
    n += 250
    let seen : @hashmap.HashMap[UInt64, Bool] = @hashmap.HashMap(
      [],
      capacity=2048,
    )
    let h2 = @hyperloglog.HLL::new(10)
    let mut s = seed
    for _ in 0..<n {
      let (_, v) = splitmix64(s)
      s = v
      if seen.get(v) is None {
        seen.set(v, true)
      }
      h2.add(v)
    }
    let est = h2.count()
    let err = (est - seen.length().to_double()).abs() /
      seen.length().to_double()
    // linear counting should track well below 5% at these densities
    assert_eq(err < 0.05, true)
  }
}

///|
test "large range: relative error within 3 sigma (1.04/sqrt(m))" {
  let m = 4096.0
  let h = @hyperloglog.HLL::new(12)
  let mut seed = 20260101UL
  let n = 100000
  let seen : @hashmap.HashMap[UInt64, Bool] = @hashmap.HashMap(
    [],
    capacity=131072,
  )
  for _ in 0..<n {
    let (_, v) = splitmix64(seed)
    seed = v
    if seen.get(v) is None {
      seen.set(v, true)
    }
    h.add(v)
  }
  let est = h.count()
  let truth = seen.length().to_double()
  let err = (est - truth).abs() / truth
  // sigma = 1.04/sqrt(m) ~ 1.62%; a fixed-seed run should sit well under 3 sigma
  assert_eq(err < 3.0 * 1.04 / m.sqrt(), true)
}
