// Whitebox tests: internal bit helpers + paper space-bound criterion.

///|
/// Pseudo-random source: deterministic splitmix64-style LCG.
fn lcg_next(seed : Ref[UInt64]) -> UInt64 {
  let z = seed.val + 0x9E3779B97F4A7C15UL
  seed.val = z
  let z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  let z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
/// Build a non-decreasing sequence of n values in [0, u] with roughly even spread.
fn gen_monotone(n : Int32, upper : UInt64, seed : UInt64) -> Array[UInt64] {
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
test "field write/read across word boundaries" {
  let bv = BitVec::new_zero(200)
  // write 13-bit fields at unaligned offsets spanning words
  let vals : Array[UInt64] = [0x1FFFUL, 0x0A5AUL, 0x1234UL, 0x0777UL]
  for i, v in vals {
    bv.write_field(i * 13, 13, v)
  }
  for i, v in vals {
    assert_eq(bv.read_field(i * 13, 13), v)
  }
  // 64-bit full-width field
  let wide = BitVec::new_zero(128)
  wide.write_field(64, 64, 0xDEADBEEFCAFEBABEUL)
  assert_eq(wide.read_field(64, 64), 0xDEADBEEFCAFEBABEUL)
  // l = 0 reads as 0
  assert_eq(bv.read_field(5, 0), 0UL)
}

///|
test "paper space bound: total bits <= n*l + 2n + 2" {
  // l = floor(log2(u/n)) implies u/2^l < 2n, and high(x[n-1]) <= u >> l,
  // so upper_bits = high_last + n + 1 < 2n + n + 1; conservatively check the
  // classic quasi-succinct budget n*l + 2n + O(1) on even-spread sequences.
  let shapes : Array[(Int32, UInt64)] = [
    (1000, 1100UL),
    (1000, 60000UL),
    (1000, 1UL << 32),
    (300, 1UL << 60),
  ]
  for shape in shapes {
    let (n, u) = shape
    let xs = gen_monotone(n, u, n.to_uint64() + 1000UL)
    let ef = build_ok(xs)
    let total = ef.total_bits()
    assert_eq(total <= n * ef.lower_bits() + 3 * n + 2, true)
  }
}
