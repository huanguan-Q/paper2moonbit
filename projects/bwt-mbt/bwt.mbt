// BWT forward (Alg. C) and inverse (Alg. D + §4.2 pseudocode).
// Strings are Array[Int] character codes (0-255 in practice).

///|
/// Convert a String to its character-code array.
pub fn str_codes(s : String) -> Array[Int32] {
  let out : Array[Int32] = []
  for ch in s {
    out.push(ch.to_int())
  }
  out
}

///|
/// Render a code array back to a String (ASCII codes as chars).
pub fn codes_str(codes : Array[Int32]) -> String {
  let buf = StringBuilder()
  for c in codes {
    buf.write_char(Int32::unsafe_to_char(c))
  }
  buf.to_string()
}

///|
/// Lexicographic comparison of the cyclic rotations of s starting at i and j.
/// Rotation(i) = s[i], s[i+1], ..., wrapping; ends at most after n symbols.
pub fn compare_rotations(s : Array[Int32], i : Int32, j : Int32) -> Int32 {
  let n = s.length()
  let mut k = 0
  while k < n {
    let a = s[(i + k) % n]
    let b = s[(j + k) % n]
    if a != b {
      return if a < b { -1 } else { 1 }
    }
    k += 1
  }
  0
}

///|
/// Sorted rotation start indices (Alg. C C1, naive comparison sort).
pub fn bwt_forward_starts(s : Array[Int32]) -> Array[Int32] {
  let n = s.length()
  let starts : Array[Int32] = []
  for i in 0..<n {
    starts.push(i)
  }
  // insertion sort — test-scale inputs; §4.1's suffix-tree speedups are
  // performance-only and deliberately not implemented (see BLUEPRINT)
  for k in 1..<n {
    let key = starts[k]
    let mut p = k - 1
    while p >= 0 && compare_rotations(s, starts[p], key) > 0 {
      starts[p + 1] = starts[p]
      p -= 1
    }
    starts[p + 1] = key
  }
  starts
}

///|
/// BWT forward transform (Alg. C): returns (L, I) where L is the last column
/// of the sorted rotation matrix and I is the row index of the original string.
pub fn bwt_forward(s : Array[Int32]) -> (Array[Int32], Int32) {
  let n = s.length()
  if n == 0 {
    return ([], 0)
  }
  let starts = bwt_forward_starts(s)
  let l : Array[Int32] = []
  let mut i_row = 0
  for k in 0..<n {
    let st = starts[k]
    // last character of the rotation starting at st
    l.push(s[(st + n - 1) % n])
    if st == 0 {
      i_row = k
    }
  }
  (l, i_row)
}

///|
/// Build the C and P arrays of §4.2: C[ch] = number of instances in L of
/// characters preceding ch in the alphabet; P[i] = instances of L[i] in
/// the prefix L[0..i-1]. Alphabet fixed to 0..255.
pub fn build_cp(l : Array[Int32]) -> (Array[Int32], Array[Int32]) {
  let n = l.length()
  let cnt = Array::make(256, 0)
  let p = Array::make(n, 0)
  // pass 1: P[i] := C[L[i]] (running count); C ends as per-symbol totals
  for i in 0..<n {
    p[i] = cnt[l[i]]
    cnt[l[i]] += 1
  }
  // pass 2: exclusive prefix sums -> C[ch] = total occurrences of chars
  // preceding ch in the alphabet
  let c = Array::make(256, 0)
  let mut sum = 0
  for ch in 0..<256 {
    sum += cnt[ch]
    c[ch] = sum - cnt[ch]
  }
  (c, p)
}

///|
/// Build the T vector (Alg. D D2): T[i] = P[i] + C[L[i]], the row of M that
/// corresponds to row i of M'. F[T[j]] == L[j].
pub fn build_t(
  l : Array[Int32],
  c : Array[Int32],
  p : Array[Int32],
) -> Array[Int32] {
  let n = l.length()
  let t = Array::make(n, 0)
  for i in 0..<n {
    t[i] = p[i] + c[l[i]]
  }
  t
}

///|
/// BWT inverse transform (Alg. D D3 + §4.2 loop): reconstruct S from (L, I).
pub fn bwt_inverse(l : Array[Int32], i : Int32) -> Array[Int32] {
  let n = l.length()
  if n == 0 {
    return []
  }
  let (c, p) = build_cp(l)
  let s = Array::make(n, 0)
  let mut idx = i
  // for j := N-1 downto 0: S[j] := L[i]; i := P[i] + C[L[i]]
  let mut j = n - 1
  while j >= 0 {
    s[j] = l[idx]
    idx = p[idx] + c[l[idx]]
    j -= 1
  }
  s
}
