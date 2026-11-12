// Whitebox tests: Brzozowski derivative algebra + smart-constructor folding.

///|
test "nullable semantics" {
  assert_eq(nullable(REmpty), false)
  assert_eq(nullable(REps), true)
  assert_eq(nullable(RChar('a')), false)
  assert_eq(nullable(mk_star(RChar('a'))), true)
  assert_eq(nullable(mk_concat(RChar('a'), mk_star(RChar('b')))), false)
  assert_eq(nullable(mk_concat(mk_star(RChar('a')), RChar('b'))), false) // a*b needs at least b
}

///|
test "derivative rules" {
  // D_a(a) = eps
  assert_eq(derivative('a', RChar('a')), REps)
  // D_b(a) = empty
  assert_eq(derivative('b', RChar('a')), REmpty)
  // D_a(a*) = concat(REps, a*) which folds smartly to a*
  assert_eq(derivative('a', mk_star(RChar('a'))), mk_star(RChar('a')))
  // D_a(eps) = empty
  assert_eq(derivative('a', REps), REmpty)
  // range membership
  assert_eq(derivative('5', RRange('0', '9')), REps)
  assert_eq(derivative('x', RRange('0', '9')), REmpty)
}

///|
test "smart constructors fold" {
  // r | r = r
  let r = RChar('a')
  assert_eq(mk_union([r, r]), r)
  // eps . r = r ; r . eps = r
  assert_eq(mk_concat(REps, r), r)
  assert_eq(mk_concat(r, REps), r)
  // empty . r = empty
  assert_eq(mk_concat(REmpty, r), REmpty)
  // (r*)* = r*
  assert_eq(mk_star(mk_star(r)), mk_star(r))
  // union drops empty branches
  assert_eq(mk_union([REmpty, r, REmpty]), r)
}

///|
test "render is canonical for structurally equal regexes" {
  let r1 = mk_union([RChar('a'), mk_star(RChar('b'))])
  let r2 = mk_union([mk_star(RChar('b')), RChar('a')])
  // same leaves -> same rendered set (order preserved, but folding dedups)
  let d1 = derivative('a', r1)
  let d2 = derivative('a', r2)
  assert_eq(render(d1) == render(d2), true)
}

///|
test "memoized derivative equals naive derivative" {
  let r = mk_concat(mk_star(RChar('a')), RRange('0', '9'))
  let memo : @hashmap.HashMap[String, Regex] = HashMap([], capacity=16)
  for c in ['a', 'b', '0', '9'] {
    let m = memo_derivative(memo, c, r)
    assert_eq(render(m) == render(derivative(c, r)), true)
  }
}
