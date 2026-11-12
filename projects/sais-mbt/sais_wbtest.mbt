// Definitional judgments for the suffix array (Manber-Myers definition):
// SA is a permutation; SA is sorted; SA agrees with the naive oracle.

///|
/// Naive suffix comparison oracle: -1/0/+1 as suf(a) <=> suf(b) over v.
fn suffix_cmp(v : Array[Int32], a : Int32, b : Int32) -> Int32 {
  let n = v.length()
  let mut i = 0
  while a + i < n && b + i < n {
    if v[a + i] != v[b + i] {
      return if v[a + i] < v[b + i] { -1 } else { 1 }
    }
    i += 1
  }
  // shorter suffix is smaller
  let la = n - a
  let lb = n - b
  if la == lb {
    0
  } else if la < lb {
    -1
  } else {
    1
  }
}

///|
/// Naive O(n^2 log n) suffix array oracle for tests only.
fn naive_suffix_array(v : Array[Int32]) -> Array[Int32] {
  let n = v.length()
  let idx : Array[Int32] = []
  for i in 0..<n {
    idx.push(i)
  }
  idx.sort_by(fn(a : Int32, b : Int32) -> Int32 { suffix_cmp(v, a, b) })
  idx
}

///|
test "banana known vector (T-KNOWN)" {
  // public-reference vector: banana -> [5,3,1,0,4,2]
  let sa = suffix_array("banana")
  let expect : Array[Int32] = [5, 3, 1, 0, 4, 2]
  assert_eq(sa == expect, true)
}

///|
test "SA is a permutation of 0..n-1 (T-PERM)" {
  let rng = LCG::new(2026)
  for trial in 0..<50 {
    let n = trial % 40 + 1
    let v : Array[Int32] = []
    for _ in 0..<n {
      v.push((rng.next_u64() % 5UL).to_int() + 1)
    }
    v.push(0)
    let m = n + 1
    let sa = sais_core(v, 6)
    // permutation check over the full SA (sentinel suffix included)
    let seen = Array::make(m, false)
    for i in 0..<m {
      let p = sa[i]
      assert_eq(p >= 0 && p < m, true)
      assert_eq(seen[p], false)
      seen[p] = true
    }
  }
}

///|
test "SA is lexicographically sorted (T-ORDER)" {
  let rng = LCG::new(31)
  for trial in 0..<50 {
    let n = trial % 60 + 2
    let v : Array[Int32] = []
    for _ in 0..<n {
      v.push((rng.next_u64() % 6UL).to_int() + 1)
    }
    v.push(0)
    let m = n + 1
    let sa = sais_core(v, 7)
    let lim = m - 1
    for i in 0..<lim {
      assert_eq(suffix_cmp(v, sa[i], sa[i + 1]) <= 0, true)
    }
  }
}

///|
test "agreement with naive oracle on random strings (T-AGREE-NAIVE)" {
  let rng = LCG::new(999)
  for trial in 0..<20 {
    let n = trial % 120 + 1
    let alpha = 3 + trial % 4
    let v : Array[Int32] = []
    for _ in 0..<n {
      v.push((rng.next_u64() % alpha.to_uint64()).to_int() + 1)
    }
    v.push(0)
    let sa = sais_core(v, alpha + 1)
    let oracle = naive_suffix_array(v)
    let mut agree = sa.length() == oracle.length()
    for i in 0..<v.length() {
      if sa[i] != oracle[i] {
        agree = false
      }
    }
    assert_eq(agree, true)
  }
}

///|
test "edge cases: empty, single, all-equal (T-EDGE)" {
  assert_eq(sais_core([0], 1) == [0], true)
  let one = sais_core([3, 0], 4)
  assert_eq(one == [1, 0], true)
  // all-equal with sentinel: sentinel suffix first, then length descending
  let v = Array::make(6, 2)
  v[5] = 0
  let sa = sais_core(v, 3)
  let expect : Array[Int32] = [5, 4, 3, 2, 1, 0]
  assert_eq(sa == expect, true)
}

///|
test "string API agrees with core over generated texts (T-STR)" {
  let rng = LCG::new(77)
  for trial in 0..<15 {
    let n = trial % 50 + 3
    let buf = StringBuilder()
    for _ in 0..<n {
      // alphabet a..e
      let code = 97 + (rng.next_u64() % 5UL).to_int()
      buf.write_char(Int::unsafe_to_char(code))
    }
    let text = buf.to_string()
    let sa = suffix_array(text)
    // independent oracle: build codes (rank+1) + sentinel, naive sort
    let codes : Array[Int32] = []
    for ch in text {
      codes.push(ch.to_int() - 96)
    }
    codes.push(0)
    let oracle_full = naive_suffix_array(codes)
    let oracle : Array[Int32] = []
    for i in 1..<oracle_full.length() {
      oracle.push(oracle_full[i])
    }
    assert_eq(sa == oracle, true)
  }
}
