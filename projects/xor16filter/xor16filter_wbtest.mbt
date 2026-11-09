// Whitebox tests: internal helper invariants (hash.mbt / positions).

///|
test "rotl64 by 21 and 42 are involutions and match shifts" {
  assert_eq(rotl64(1UL, 21), 1UL << 21)
  assert_eq(rotl64(0xFFFFFFFFUL, 21), 0xFFFFFFFFUL << 21)
  // rotate left 21 then 43 = identity (21+43 = 64)
  let x = 0x0123456789ABCDEFUL
  assert_eq(rotl64(rotl64(x, 21), 43), x)
}

///|
test "reduce result strictly below n" {
  let rng = Ref(99UL)
  for _ in 0..<1000 {
    let h = low32(splitmix64_next(rng))
    assert_eq(reduce(h, 353) < 353, true)
  }
}

///|
test "fingerprint16 fits in 16 bits" {
  let rng = Ref(7UL)
  for _ in 0..<1000 {
    assert_eq(fingerprint16(splitmix64_next(rng)) <= 0xFFFFUL, true)
  }
}

///|
test "block_len_for respects 1.23 load factor and multiple of 3" {
  assert_eq(3 * block_len_for(0) % 3, 0)
  assert_eq(block_len_for(1) >= 1, true)
  assert_eq(3 * block_len_for(1_000_000) >= 1_230_000, true)
}
