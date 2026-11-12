// Property-based tests via moonbitlang/quickcheck (round 19 recipe upgrade):
// the paper's full-judgment criteria (§4.1 f^V(i) ∈ V, Thm 4.1.1 monotonicity
// consequence) expressed as generated properties instead of hand-built cases.

///|
test "member property: assignment always inside the view (QC-MEMBER)" {
  // for any bucket count n (1..32) and any item, assign(item) must be a
  // registered bucket — the ranged-hash definition f^V(i) ∈ V.
  @quickcheck.check(
    fn(n : Int32) -> Bool {
      let buckets = if n < 0 { 1 } else { n % 32 + 1 }
      let h = @chash.RangedHash::new(seed=0x9E37UL, points_per_bucket=8)
      let mut b = 0
      while b < buckets {
        h.add_bucket(b)
        b += 1
      }
      let owner = h.assign((buckets * 7919 + 13) % 100000)
      h.has_bucket(owner)
    },
    seed=0xC0FFEEUL,
    count=300,
  )
}

///|
test "smoothness property: adding a bucket only steals for itself (QC-SMOOTH)" {
  // for any generated bucket layout, after adding one new bucket every
  // changed assignment must land on the NEW bucket ("item may move from an
  // old bucket to a new bucket, but not from one old bucket to another").
  @quickcheck.check(
    fn(n : Int32) -> Bool {
      let base = if n < 0 { 1 } else { n % 16 + 1 }
      let h = @chash.RangedHash::new(seed=0xD1CEUL, points_per_bucket=8)
      let mut b = 0
      while b < base {
        h.add_bucket(b)
        b += 1
      }
      let items : Array[Int32] = []
      let rng = @chash.LCG::new(base.to_uint64() * 2654435761UL + 11UL)
      for _ in 0..<200 {
        items.push((rng.next_u64() % 50000UL).to_int())
      }
      let before : Array[Int32] = []
      for item in items {
        before.push(h.assign(item))
      }
      let new_bucket = base
      h.add_bucket(new_bucket)
      let mut ok = true
      for i in 0..<items.length() {
        let after = h.assign(items[i])
        if before[i] != after && after != new_bucket {
          ok = false
        }
      }
      ok
    },
    seed=999983UL,
    count=200,
  )
}
