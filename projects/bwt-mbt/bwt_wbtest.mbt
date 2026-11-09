// Paper-criterion tests: BWT forward/inverse (Alg. C/D + §4.2 pseudocode).
// All worked-example values verified against the paper text.

///|
test "forward BWT matches paper example (T-C-FWD)" {
  // Alg. C: S='abraca', N=6 -> L='caraab', I=1
  let s = str_codes("abraca")
  let (l, i) = bwt_forward(s)
  assert_eq(codes_str(l), "caraab")
  assert_eq(i, 1)
}

///|
test "T vector matches paper example (T-C-TVEC)" {
  // Alg. D D2: L='caraab' -> T = (4 0 5 1 2 3)
  let l = str_codes("caraab")
  let (c, p) = build_cp(l)
  let t = build_t(l, c, p)
  assert_eq(t, [4, 0, 5, 1, 2, 3])
}

///|
test "inverse BWT reconstructs paper example (T-D-INV)" {
  // Alg. D D3: (L='caraab', I=1) -> S='abraca'
  let l = str_codes("caraab")
  let s = bwt_inverse(l, 1)
  assert_eq(codes_str(s), "abraca")
}

///|
test "BWT roundtrip over diverse shapes (T-BWT-RT)" {
  // repetitive, all-same, single, alternating, empty-of-conflicts, longer text
  let cases = [
    "missississississippi_repeated_mississippi_mississippi", "aaaaaaaaaaaaaaa", "x",
    "abababababababab", "the quick brown fox jumps over the lazy dog",
  ]
  for case in cases {
    let s = str_codes(case)
    let (l, i) = bwt_forward(s)
    let back = bwt_inverse(l, i)
    assert_eq(codes_str(back), case)
    // F is a permutation of L: equal length (count consistency D1)
    assert_eq(l.length(), s.length())
  }
  // empty string edge: defined as identity (no rotations)
  let (l0, i0) = bwt_forward([])
  assert_eq(l0.length(), 0)
  assert_eq(bwt_inverse(l0, i0).length(), 0)
}

///|
test "rotation comparison agrees with lexicographic order of rotations" {
  // sorting invariant: for sorted rotation starts, comparing rotations from
  // those starts is ascending (the core sort property, Alg. C C1)
  let s = str_codes("abraca")
  let n = s.length()
  let starts = bwt_forward_starts(s)
  let lim = n - 1
  for k in 0..<lim {
    assert_eq(compare_rotations(s, starts[k], starts[k + 1]) <= 0, true)
  }
}
