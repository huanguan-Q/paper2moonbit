// Paper-criterion tests: end-to-end compress/decompress pipeline.
// Judgment: lossless roundtrip + effective compression on repetitive text
// (the paper's core claim: BWT+MTF makes data easy for simple back-end coders).

///|
test "end-to-end pipeline is lossless (T-E2E)" {
  let cases = [
    "abraca", "mississippi_mississippi_mississippi_mississippi", "banana_banana_banana_banana_banana",
    "the quick brown fox jumps over the lazy dog", "aaaaaaaaaaaaaaaaaaaa", "w",
  ]
  for case in cases {
    let s = str_codes(case)
    let out = bwt_compress(s)
    let back = bwt_decompress(out)
    assert_eq(codes_str(back), case)
  }
}

///|
test "pipeline compresses repetitive text (compression effectiveness)" {
  // 30 repeats of 'mississippi': clustered rotations must collapse into
  // low-rank MTF streams and long zero runs -> output strictly smaller
  let s : Array[Int32] = []
  for _ in 0..<30 {
    for c in str_codes("mississippi") {
      s.push(c)
    }
  }
  let out = bwt_compress(s)
  assert_eq(out.zr.length() < s.length(), true)
  // and random-ish non-clustered text still roundtrips losslessly
  let noise = str_codes("qwertyuiopasdfghjklzxcvbnm_1234567890_QWERTY")
  assert_eq(
    codes_str(bwt_decompress(bwt_compress(noise))),
    "qwertyuiopasdfghjklzxcvbnm_1234567890_QWERTY",
  )
}

///|
test "pipeline handles adversarial all-same block" {
  // worst case for rotation sorting: every rotation identical
  let s = Array::make(50, 'a'.to_int())
  let out = bwt_compress(s)
  assert_eq(
    codes_str(bwt_decompress(out)),
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
}
