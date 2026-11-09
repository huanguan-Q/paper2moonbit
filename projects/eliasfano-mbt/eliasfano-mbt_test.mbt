///|
/// Pseudo-random source: deterministic splitmix64-style LCG (independent per test).
fn lcg_next(seed : Ref[UInt64]) -> UInt64 {
  let z = seed.val + 0x9E3779B97F4A7C15UL
  seed.val = z
  let z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  let z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
/// Build a non-decreasing sequence of n values in [0, u] with roughly even spread.
fn gen_monotone(n : Int, upper : UInt64, seed : UInt64) -> Array[UInt64] {
  let rng = Ref(seed)
  let xs : Array[UInt64] = []
  let mut cur : UInt64 = 0UL
  let n_u = n.to_uint64()
  let step = if upper >= n_u { upper / n_u } else { 0UL }
  for _ in 0..<n {
    cur += lcg_next(rng) % (step + 1UL)
    xs.push(cur)
  }
  xs
}

///|
test "l computation: known values" {
  // deterministic: xs[i] = i*1024, u = last = 1023*1024
  // q = floor(u/n) = 1023 -> l = floor(log2(1023)) = 9
  let xs : Array[UInt64] = []
  for i in 0..<1024 {
    xs.push(i.to_uint64() * 1024UL)
  }
  let ef = match @eliasfano.build(xs) {
    Ok(f) => f
    Err(msg) => {
      println(msg)
      abort("build failed: \{msg}")
    }
  }
  assert_eq(ef.lower_bits(), 9)
}

///|
test "roundtrip: edge cases" {
  // n = 0
  assert_eq(match @eliasfano.build([]) { Ok(_) => true; Err(_) => false }, true)
  // n = 1
  let one = @eliasfano.build_ok([0UL])
  assert_eq(one.length() == 1 && one.get(0) == 0UL, true)
  // duplicates
  let dup = @eliasfano.build_ok([5UL, 5UL, 5UL, 5UL])
  for i in 0..<4 {
    assert_eq(dup.get(i), 5UL)
  }
  // max universe value
  let top = @eliasfano.build_ok([0xFFFFFFFFFFFFFFFFUL])
  assert_eq(top.get(0), 0xFFFFFFFFFFFFFFFFUL)
}

///|
test "roundtrip: random monotone sequences, dense to sparse" {
  let rng = Ref(42UL)
  // (n, u) shapes: dense, mixed, sparse, very sparse
  let shapes : Array[(Int, UInt64)] = [
    (1000, 1100UL), (1000, 60000UL), (1000, 1UL << 32), (300, 1UL << 60),
  ]
  for shape in shapes {
    let (n, u) = shape
    let xs = gen_monotone(n, u, lcg_next(rng))
    let ef = @eliasfano.build_ok(xs)
    assert_eq(ef.length(), n)
    for i in 0..<n {
      assert_eq(ef.get(i), xs[i])
    }
  }
}

///|
test "get is monotone non-decreasing" {
  let xs = gen_monotone(500, 1UL << 40, 99UL)
  let ef = @eliasfano.build_ok(xs)
  for i in 1..<500 {
    assert_eq(ef.get(i) >= ef.get(i - 1), true)
  }
}

///|
test "next_ge matches linear-scan oracle" {
  let xs = gen_monotone(800, 1UL << 30, 123UL)
  let ef = @eliasfano.build_ok(xs)
  let rng = Ref(777UL)
  for _ in 0..<2000 {
    let q = lcg_next(rng) % (1UL << 31)
    // oracle: first xs[i] >= q
    let mut expect : Option[UInt64] = None
    for v in xs {
      if v >= q {
        expect = Some(v)
        break
      }
    }
    assert_eq(ef.next_ge(q), expect)
  }
  // below min and above max
  let lo = @eliasfano.build_ok([10UL, 20UL])
  assert_eq(lo.next_ge(0UL), Some(10UL))
  assert_eq(lo.next_ge(21UL), None)
}

///|
test "build rejects non-monotone input" {
  assert_eq(
    match @eliasfano.build([5UL, 3UL]) {
      Err(_) => true
      Ok(_) => false
    },
    true,
  )
}
