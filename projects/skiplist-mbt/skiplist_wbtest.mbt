// Paper-criterion tests: Pugh 1990 Skip Lists (Figures 2/4/5 + analysis).

///|
/// Sorted-array oracle: reference model for the seeded operation sequence.
fn oracle_insert(a : Array[Int32], k : Int32) -> Unit {
  // skip list semantics (Fig. 4): duplicate key UPDATES, never duplicates
  if oracle_contains(a, k) {
    return
  }
  let mut lo = 0
  let mut hi = a.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if a[mid] < k {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  a.insert(lo, k)
}

///|
fn oracle_remove(a : Array[Int32], k : Int32) -> Unit {
  let mut lo = 0
  let mut hi = a.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if a[mid] < k {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo < a.length() && a[lo] == k {
    let _ = a.remove(lo)
  }
}

///|
fn oracle_contains(a : Array[Int32], k : Int32) -> Bool {
  let mut lo = 0
  let mut hi = a.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if a[mid] < k {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo < a.length() && a[lo] == k
}

///|
test "seeded random op sequence matches oracle (T-ORACLE)" {
  let rng = LCG::new(2026)
  let sl = SkipList::new(16)
  let oracle : Array[Int32] = []
  for _ in 0..<300 {
    let op = (rng.next_u64() % 3UL).to_int()
    let key = (rng.next_u64() % 200UL).to_int()
    if op == 0 {
      sl.insert(key, key * 10)
      oracle_insert(oracle, key)
    } else if op == 1 {
      oracle_remove(oracle, key)
      let _ = sl.delete(key)
    } else {
      assert_eq(sl.search(key) == oracle_contains(oracle, key), true)
    }
    assert_eq(sl.to_level1_keys(), oracle)
  }
}

///|
test "randomLevel matches geometric distribution, p=1/2 (T-DISTRIB)" {
  let rng = LCG::new(7)
  let max_level = 16
  let trials = 10000
  let mut lvl1 = 0
  let mut ge4 = 0
  for _ in 0..<trials {
    let l = random_level(rng, 0.5, max_level)
    // cap invariant (Fig.5: lvl < MaxLevel guard)
    assert_eq(l >= 1 && l <= max_level, true)
    if l == 1 {
      lvl1 += 1
    }
    if l >= 4 {
      ge4 += 1
    }
  }
  // P(level=1) = 1/2 -> ~5000 of 10000; P(level>=4) = 1/8 -> ~1250
  assert_eq(lvl1 >= 4600 && lvl1 <= 5400, true)
  assert_eq(ge4 >= 1050 && ge4 <= 1450, true)
}

///|
test "cap_level is bounded in [1, max_level] (T-CAP)" {
  for max_level in [1, 2, 16] {
    for run in 0..<(max_level + 4) {
      let l = cap_level(run, max_level)
      assert_eq(l >= 1, true)
      assert_eq(l <= max_level, true)
    }
  }
  // boundary: run >= max_level-1 saturates at max_level
  assert_eq(cap_level(0, 1), 1)
  assert_eq(cap_level(15, 16), 16)
  assert_eq(cap_level(100, 16), 16)
}

///|
test "duplicate insert updates value, size unchanged (T-DUP)" {
  let sl = SkipList::new(16)
  sl.insert(42, 1)
  sl.insert(42, 2)
  assert_eq(sl.size(), 1)
  assert_eq(sl.get(42), 2)
}

///|
test "structural invariants hold after seeded ops (T-ORDER)" {
  let rng = LCG::new(99)
  let sl = SkipList::new(16)
  for _ in 0..<200 {
    let key = (rng.next_u64() % 500UL).to_int()
    let op = (rng.next_u64() % 2UL).to_int()
    if op == 0 {
      sl.insert(key, key)
    } else {
      let _ = sl.delete(key)
    }
    assert_eq(sl.check_invariants(), true)
  }
  // deleting everything shrinks list level back to 1 (Fig.4 tail loop)
  let sl2 = SkipList::new(16)
  for k in 0..<100 {
    sl2.insert(k, k)
  }
  assert_eq(sl2.current_level() > 1, true)
  for k in 0..<100 {
    let _ = sl2.delete(k)
  }
  assert_eq(sl2.size(), 0)
  assert_eq(sl2.current_level(), 1)
}

///|
test "mean search comparisons near L(n)/p + 1/(1-p) + 1 (T-COST)" {
  // n=4096, p=1/2: L(n)=12, expected ~ 12/0.5 + 2 + 1 = 27 comparisons
  let rng = LCG::new(314)
  let sl = SkipList::new(16)
  for k in 0..<4096 {
    sl.insert(k * 7 % 4096, k)
  }
  let mut total = 0
  let queries = 200
  for _ in 0..<queries {
    let key = (rng.next_u64() % 4096UL).to_int()
    let _ = sl.search(key)
    total += sl.last_comparisons()
  }
  let mean = total.to_double() / queries.to_double()
  assert_eq(mean >= 15.0 && mean <= 60.0, true)
}
