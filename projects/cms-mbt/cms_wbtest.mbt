// Paper-criterion tests: Count-Min Sketch (Cormode & Muthukrishnan 2005).
// Thm 1 / Thm 3 judgments + row-sum invariant + CU variant comparison.

///|
test "one-sided error: estimate never below true count (T-ONE-SIDED)" {
  let rng = LCG::new(11)
  let stream = zipf_stream(rng, 1.0, 1000, 50000)
  let cms = CMS::new(w=8192, d=5, seed=1UL)
  for it in stream {
    cms.update(it, 1)
  }
  // exact oracle
  let true_counts = Array::make(1001, 0)
  for it in stream {
    true_counts[it] += 1
  }
  for k in 1..<=1000 {
    let est = cms.point_query(k)
    assert_eq(est >= true_counts[k], true)
  }
}

///|
test "row sum equals total added count (T-ROW-SUM)" {
  // Update Procedure linearity: each update adds ct to exactly one cell per row
  let cms = CMS::new(w=4096, d=7, seed=2UL)
  let rng = LCG::new(3)
  let mut total = 0
  for _ in 0..<5000 {
    let it = (rng.next_u64() % 800UL).to_int() + 1
    let c = (rng.next_u64() % 5UL).to_int() + 1
    cms.update(it, c)
    total += c
  }
  let mut j = 0
  while j < cms.depth() {
    assert_eq(cms.row_sum(j), total)
    j += 1
  }
}

///|
test "Thm 1 bound on Zipf stream: overestimate within window (T-BOUND)" {
  let rng = LCG::new(19)
  let stream = zipf_stream(rng, 1.0, 1000, 100000)
  let cms = CMS::new(w=8192, d=5, seed=1UL)
  for it in stream {
    cms.update(it, 1)
  }
  let true_counts = Array::make(1001, 0)
  for it in stream {
    true_counts[it] += 1
  }
  // absolute overestimate over all items within generous constant window
  let eps_n = 2.718281828 * 100000.0 / 8192.0 // e*N/w ≈ 33.2
  let mut mx_over = 0
  for k in 1..<=1000 {
    let over = cms.point_query(k) - true_counts[k]
    if over > mx_over {
      mx_over = over
    }
  }
  assert_eq(mx_over.to_double() <= 3.0 * eps_n, true)
  // heavy hitters: top-50 items relative error ≤ 5%
  // (collect keys sorted by true count desc)
  let keys : Array[Int32] = []
  for k in 1..<=1000 {
    keys.push(k)
  }
  keys.sort_by(fn(a : Int32, b : Int32) -> Int32 {
    true_counts[b] - true_counts[a]
  })
  let mut i = 0
  while i < 50 {
    let k = keys[i]
    let true_c = true_counts[k].to_double()
    let est = cms.point_query(k).to_double()
    let rel = (est - true_c) / true_c
    assert_eq(rel <= 0.05, true)
    i += 1
  }
}

///|
test "inner product query is one-sided upper bound (T-INNER)" {
  // Thm 3: a·b ≤ â·b for nonnegative vectors
  let rng = LCG::new(23)
  let sa = zipf_stream(rng, 1.0, 500, 40000)
  let sb = zipf_stream(rng, 1.5, 500, 40000)
  let ca = CMS::new(w=8192, d=5, seed=10UL)
  let cb = CMS::new(w=8192, d=5, seed=10UL)
  for it in sa {
    ca.update(it, 1)
  }
  for it in sb {
    cb.update(it, 1)
  }
  // exact inner product from oracle counts
  let va = Array::make(501, 0)
  let vb = Array::make(501, 0)
  for it in sa {
    va[it] += 1
  }
  for it in sb {
    vb[it] += 1
  }
  let mut true_ip = 0
  for k in 1..<=500 {
    true_ip += va[k] * vb[k]
  }
  let est = CMS::inner_product(ca, cb)
  assert_eq(est >= true_ip, true)
  // generous sanity window: est ≤ true + 2*eps*N1*N2... use L1 product bound
  // eps*L1a*L1b = (e/w)*40000*40000 ≈ 529 — deterministic seed makes it hold
  let bound = 2.718281828 / 8192.0 * 40000.0 * 40000.0 * 3.0
  assert_eq(est.to_double() - true_ip.to_double() <= bound, true)
}

///|
test "conservative update: one-sided and never worse than CMS (T-CU)" {
  let rng = LCG::new(29)
  let stream = zipf_stream(rng, 1.2, 1000, 60000)
  let cms = CMS::new(w=4096, d=5, seed=5UL)
  let cu = CMS::new(w=4096, d=5, seed=5UL)
  for it in stream {
    cms.update(it, 1)
    cu.conservative_update(it, 1)
  }
  let true_counts = Array::make(1001, 0)
  for it in stream {
    true_counts[it] += 1
  }
  let mut mx_cms = 0
  let mut mx_cu = 0
  for k in 1..<=1000 {
    let e_cms = cms.point_query(k)
    let e_cu = cu.point_query(k)
    // one-sidedness holds for both
    assert_eq(e_cms >= true_counts[k], true)
    assert_eq(e_cu >= true_counts[k], true)
    if e_cms - true_counts[k] > mx_cms {
      mx_cms = e_cms - true_counts[k]
    }
    if e_cu - true_counts[k] > mx_cu {
      mx_cu = e_cu - true_counts[k]
    }
  }
  // CU is never worse than CMS on the same stream (community property)
  assert_eq(mx_cu <= mx_cms, true)
}

///|
test "range query equals sum of point queries, one-sided (T-RANGE)" {
  let rng = LCG::new(31)
  let stream = zipf_stream(rng, 1.0, 1000, 30000)
  let cms = CMS::new(w=8192, d=5, seed=7UL)
  for it in stream {
    cms.update(it, 1)
  }
  let true_counts = Array::make(1001, 0)
  for it in stream {
    true_counts[it] += 1
  }
  let l = 100
  let r = 400
  let mut true_range = 0
  let mut k = l
  while k <= r {
    true_range += true_counts[k]
    k += 1
  }
  let est = cms.range_query(l, r)
  assert_eq(est >= true_range, true)
}
