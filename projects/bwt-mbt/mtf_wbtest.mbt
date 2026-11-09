// Paper-criterion tests: MTF (Alg. M/W) and zero-run coding (§5 variant).

///|
test "MTF encode matches paper example (T-MTF)" {
  // Alg. M M1: Y=[a,b,c,r] init, L='caraab' -> R=(2 1 3 1 0 3)
  // With the paper's 4-symbol alphabet. Our implementation uses a 256-code
  // alphabet with initial list 0..255, so replicate the paper's list by
  // restricting codes: a=97, b=98, c=99, r=114 and checking via a dedicated
  // small-alphabet entry point.
  let l = [
    'c'.to_int(),
    'a'.to_int(),
    'r'.to_int(),
    'a'.to_int(),
    'a'.to_int(),
    'b'.to_int(),
  ]
  let r = mtf_encode_small(l, [
    'a'.to_int(),
    'b'.to_int(),
    'c'.to_int(),
    'r'.to_int(),
  ])
  assert_eq(r, [2, 1, 3, 1, 0, 3])
  // Alg. W W2: decode restores L
  let back = mtf_decode_small(r, [
    'a'.to_int(),
    'b'.to_int(),
    'c'.to_int(),
    'r'.to_int(),
  ])
  assert_eq(back, l)
}

///|
test "MTF full-alphabet roundtrip and locality (T-MTF)" {
  let s = str_codes("mississippi_mississippi_mississippi")
  let r = mtf_encode(s)
  let back = mtf_decode(r)
  assert_eq(back, s)
  // locality property: repeated characters reappear at low ranks; the mean
  // rank must stay well below the alphabet size for clustered text
  let mut sum = 0
  for x in r {
    sum += x
  }
  let mean = sum.to_double() / r.length().to_double()
  assert_eq(mean < 64.0, true)
  // single char / empty edge
  assert_eq(mtf_decode(mtf_encode(str_codes("z"))), str_codes("z"))
  assert_eq(mtf_decode(mtf_encode([])), [])
}

///|
test "zero-run coding roundtrip and compression (T-ZR)" {
  // §5 variant: runs of zeros in R are replaced by a (RUN, len) marker pair
  let r = [5, 0, 0, 0, 0, 0, 0, 3, 0, 0, 1]
  let z = zero_run_encode(r)
  assert_eq(zero_run_decode(z), r)
  // all-zero input compresses strictly below its original length
  let allzero = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let z2 = zero_run_encode(allzero)
  assert_eq(z2.length() < allzero.length(), true)
  assert_eq(zero_run_decode(z2), allzero)
  // no zeros at all: identity passthrough
  let nz = [9, 4, 7]
  assert_eq(zero_run_encode(nz), nz)
  assert_eq(zero_run_decode(nz), nz)
}
