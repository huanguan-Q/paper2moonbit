///|
// Whitebox: runtime spot-checks of the Z3-verified properties.

///|
test "verified rho bounds hold at runtime" {
  // property proven by Z3: 1 <= rho(x,bits) <= bits+1 for x >= 0
  let cases = [0, 1, 2, 3, 0xFF, 1024, 0x15555]
  for x in cases {
    for bits in [1, 4, 16, 60] {
      let r = rho(x, bits)
      assert_eq(r >= 1 && r <= bits + 1, true)
    }
  }
  // semantics: rho(0,8)=9 (no set bit), rho(1,8)=1 (LSB set), rho(2,8)=2
  assert_eq(rho(0, 8), 9)
  assert_eq(rho(1, 8), 1)
  assert_eq(rho(2, 8), 2)
  assert_eq(rho(4, 8), 3)
}

///|
test "verified update_reg monotonicity" {
  // proven: update_reg(prev,v,bits) >= max(prev,v) and <= bits+1
  assert_eq(update_reg(3, 1, 8), 3)
  assert_eq(update_reg(3, 5, 8), 5)
  assert_eq(update_reg(9, 5, 8), 9)
}

///|
test "verified register_of range" {
  // proven: 0 <= register_of(h,m) < m for h >= 0, m > 0
  for h in [0, 1, 1023, 1024, 999999] {
    let j = register_of(h, 1024)
    assert_eq(j >= 0 && j < 1024, true)
  }
}
