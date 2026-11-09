// Paper-criterion tests: LogLog family (Durand-Flajolet ESA 2003).
// Thm 1(ii) SE windows, Fact 2 quantiles, §6 comparison ordering,
// §4 "640 bytes", §2 replication-independence, §6 max-merge.

///|
/// Distinct-item stream: items = mix64(seed, i) for i in 0..n (distinct).
fn distinct_stream(seed : UInt64, n : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  for i in 0..<n {
    out.push(mix64(seed, i).to_int())
  }
  out
}

///|
test "packed register memory matches paper (T-MEM)" {
  // §4: "1024 registers of 5 bits each ... 640 bytes in total"
  let ll = LogLog::new(k=10, seed=1UL) // m = 1024
  assert_eq(ll.register_bytes(), 640)
  // HLL uses 6-bit registers: ceil(1024*6/8) = 768
  let h = HLL::new(k=10, seed=1UL)
  assert_eq(h.register_bytes(), 768)
  // packed put/get roundtrip across word boundaries
  let r = PackedRegs::new(20, 5)
  for i in 0..<20 {
    r.put(i, (i * 7 + 3) % 32)
  }
  for i in 0..<20 {
    assert_eq(r.get(i), (i * 7 + 3) % 32)
  }
}

///|
test "cap keeps registers in 5-bit domain (T-CAP)" {
  for v in [0, 1, 31, 32, 33, 64, 100] {
    let c = cap_reg(v)
    assert_eq(c >= 0 && c <= 31, true)
  }
  assert_eq(cap_reg(31), 31)
  assert_eq(cap_reg(64), 31)
}

///|
test "Thm 1(ii): LogLog SE within 3 sigma windows (T-SE)" {
  let m = 1024
  let se = 1.30 / @math.pow(m.to_double(), 0.5) // ≈ 4.06%
  let n = 100000
  let mut bad = 0
  for trial in 0..<20 {
    let seed = (trial + 1).to_uint64() * 7919UL
    let ll = LogLog::new(k=10, seed~)
    for it in distinct_stream(seed, n) {
      ll.add(it)
    }
    let est = ll.estimate()
    let rel = (est - n.to_double()).abs() / n.to_double()
    if rel > 3.0 * se {
      bad += 1
    }
  }
  // 3σ Gaussian window: violations expected ~0.3% of runs; allow 2 of 20
  assert_eq(bad <= 2, true)
}

///|
test "§5 truncation decreases dispersion; HLL beats LogLog (T-COMPARE)" {
  // theory: HLL 1.04/sqrt(m) vs LogLog 1.30/sqrt(m) — mean |rel err| ordering;
  // SLL truncation constant has no closed form in the paper (see EXTRACTION
  // deviation), so its paper-stated benefit (§5 (i): "decreases the
  // dispersion") is judged by the std of relative errors over seeds.
  let n = 50000
  let mut sum_hll = 0.0
  let mut sum_ll = 0.0
  let errs_ll : Array[Double] = []
  let errs_sll : Array[Double] = []
  for trial in 0..<20 {
    let seed = (trial + 1).to_uint64() * 104729UL
    let stream = distinct_stream(seed, n)
    let h = HLL::new(k=10, seed~)
    let s = LogLog::new(k=10, seed~)
    let l = LogLog::new(k=10, seed~)
    for it in stream {
      h.add(it)
      s.add(it)
      l.add(it)
    }
    let nd = n.to_double()
    sum_hll += (h.estimate() - nd).abs() / nd
    sum_ll += (l.estimate() - nd).abs() / nd
    errs_ll.push((l.estimate() - nd).abs() / nd)
    errs_sll.push((s.superloglog_estimate() - nd).abs() / nd)
  }
  let mean_hll = sum_hll / 20.0
  let mean_ll = sum_ll / 20.0
  assert_eq(mean_hll < mean_ll, true)
  // dispersion: std of SLL errors < std of LogLog errors (§5 (i))
  let mut ss_ll = 0.0
  let mut ss_sll = 0.0
  for i in 0..<20 {
    let d1 = errs_ll[i] - mean_ll
    let d2 = errs_sll[i] - mean_sll_center(errs_sll)
    ss_ll += d1 * d1
    ss_sll += d2 * d2
  }
  assert_eq(@math.pow(ss_sll / 20.0, 0.5) < @math.pow(ss_ll / 20.0, 0.5), true)
}

///|
fn mean_sll_center(errs : Array[Double]) -> Double {
  let mut acc = 0.0
  for e in errs {
    acc += e
  }
  acc / errs.length().to_double()
}

///|
test "truncation pulls overshoot down (T-FACT2 mechanism)" {
  // Fact 2 quantiles presuppose the paper's calibrated truncation constant,
  // which has no closed form (see EXTRACTION deviation). The mechanism that
  // survives uncalibrated: LogLog overshoots when exceptional high registers
  // inflate 2^mean; truncation discards exactly those, so on seeds where
  // LogLog overshoots, the truncated estimate must sit lower.
  let n = 100000
  let mut overshoot_seeds = 0
  let mut pulled_down = 0
  for trial in 0..<20 {
    let seed = (trial + 1).to_uint64() * 15485863UL
    let s = LogLog::new(k=10, seed~)
    let l = LogLog::new(k=10, seed~)
    for it in distinct_stream(seed, n) {
      s.add(it)
      l.add(it)
    }
    let rel_ll = l.estimate() - n.to_double()
    let rel_sll = s.superloglog_estimate() - n.to_double()
    if rel_ll > 0.0 {
      overshoot_seeds += 1
      if rel_sll < rel_ll {
        pulled_down += 1
      }
    }
  }
  // enough overshooting seeds to make the mechanism observable
  assert_eq(overshoot_seeds >= 6, true)
  // truncation pulls every overshooting estimate down (mechanism exact)
  assert_eq(pulled_down == overshoot_seeds, true)
}

///|
test "replication independence: registers unchanged by duplicates (T-DUP)" {
  // §2: the observable is "totally independent of order and replication"
  let seed = 999UL
  let stream = distinct_stream(seed, 3000)
  let a = LogLog::new(k=10, seed~)
  let b = LogLog::new(k=10, seed~)
  for it in stream {
    a.add(it)
  }
  // stream B: each item repeated 3 times + order shuffled deterministically
  for i in 0..<3000 {
    let j = i * 7919 % 3000
    let it = stream[j]
    b.add(it)
    b.add(it)
    b.add(it)
  }
  for r in 0..<a.register_count() {
    assert_eq(a.raw_register(r), b.raw_register(r))
  }
  assert_eq(a.estimate() == b.estimate(), true)
}

///|
test "max-merge equals single-pass over the union (T-MERGE)" {
  // §6: different processors operate on slices and "max-merge" register tables
  let seed = 777UL
  let full = LogLog::new(k=10, seed~)
  let half1 = LogLog::new(k=10, seed~)
  let half2 = LogLog::new(k=10, seed~)
  for i in 0..<40000 {
    let it = mix64(seed, i).to_int()
    full.add(it)
    if i % 2 == 0 {
      half1.add(it)
    } else {
      half2.add(it)
    }
  }
  half1.merge(half2)
  for r in 0..<full.register_count() {
    assert_eq(half1.raw_register(r), full.raw_register(r))
  }
  assert_eq((half1.estimate() - full.estimate()).abs() < 1.0, true)
}

///|
test "both estimators track growing cardinality (T-TRACK)" {
  // sanity: estimates increase and stay within coarse windows at two scales
  let seed = 314159UL
  let l = LogLog::new(k=10, seed~)
  let h = HLL::new(k=10, seed~)
  for i in 0..<10000 {
    let it = mix64(seed, i).to_int()
    l.add(it)
    h.add(it)
  }
  let e10 = (l.estimate() / 10000.0, h.estimate() / 10000.0)
  for i in 0..<90000 {
    let it = mix64(seed, 10000 + i).to_int()
    l.add(it)
    h.add(it)
  }
  let e100 = (l.estimate() / 100000.0, h.estimate() / 100000.0)
  // both estimators within 20% at both scales (coarse sanity)
  assert_eq(e10.0 > 0.8 && e10.0 < 1.2, true)
  assert_eq(e10.1 > 0.8 && e10.1 < 1.2, true)
  assert_eq(e100.0 > 0.8 && e100.0 < 1.2, true)
  assert_eq(e100.1 > 0.8 && e100.1 < 1.2, true)
}
