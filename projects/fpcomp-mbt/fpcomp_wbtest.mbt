// Paper-criterion tests: floating-point compensated arithmetic
// (Goldberg 1991 Thm 8 + standard error-free transformation identities).

///|
test "IEEE semantics anchor (T-IEEE)" {
  // the equality-based "exact" judgments rest on IEEE == semantics
  assert_eq(0.0 - 0.0 == 0.0, true) // -0.0 == 0.0
  let inf = 1.0 / 0.0
  assert_eq(is_finite(inf), false)
  assert_eq(is_finite(0.0 / 0.0), false) // NaN
  assert_eq(is_finite(1.5), true)
  // 2^53 + 1 rounds back to 2^53: the T-KAHAN-EXACT premise
  let big = @math.pow(2.0, 53.0)
  assert_eq(big + 1.0 == big, true)
  assert_eq(big + 2.0 != big, true) // even units are representable
}

///|
test "Kahan summation recovers 2^53 + 1000 exactly (T-KAHAN-EXACT)" {
  // Theorem 8 strong case: after 2^53, naive summation absorbs every +1.0
  // (fl(2^53 + 1) == 2^53); the compensation counter captures each lost unit
  // so the Kahan sum is 2^53 + 1000 exactly.
  let stream = Array::make(1000, 1.0)
  let big = @math.pow(2.0, 53.0)
  let naive = naive_sum(big, stream)
  assert_eq(naive == big, true) // all 1000 units lost by naive addition
  let kahan = kahan_sum(big, stream)
  assert_eq(kahan == big + 1000.0, true) // exact recovery (Thm 8)
}

///|
test "two_sum identity consistency across random pairs (T-ID-CONSIST)" {
  // (a + b) real value == (s + e) real value implies fl(s + e) == fl(a + b);
  // s must equal fl(a + b); ordered fast_two_sum e == two_sum e.
  let rng = LCG::new(2026)
  let mut checked = 0
  for _ in 0..<20000 {
    let ea = (rng.next_u64() % 1400UL).to_int() - 700
    let eb = (rng.next_u64() % 1400UL).to_int() - 700
    let a = @math.pow(2.0, ea.to_double()) * (1.0 + rng.next_double())
    let b = @math.pow(2.0, eb.to_double()) * (1.0 + rng.next_double())
    if !is_finite(a) || !is_finite(b) {
      continue
    }
    let t = two_sum(a, b)
    // s is the rounded sum
    assert_eq(t.s == a + b, true)
    // the real-number sum identity survives rounding back
    assert_eq(t.s + t.e == a + b, true)
    checked += 1
    // ordered variant agrees when |a| >= |b|
    if a.abs() >= b.abs() {
      let f = fast_two_sum(a, b)
      assert_eq(f.e == t.e, true)
    }
  }
  assert_eq(checked > 15000, true)
}

///|
test "Sterbenz: subtraction exact inside the scale window (T-STERBENZ)" {
  // x/2 <= y <= 2x implies fl(y - x) == y - x exactly (Sterbenz 1974)
  let rng = LCG::new(77)
  for _ in 0..<10000 {
    let e = (rng.next_u64() % 1000UL).to_int() - 500
    let x = @math.pow(2.0, e.to_double()) * (1.0 + rng.next_double())
    let frac = 0.5 + rng.next_double() * 1.5
    let y = x * frac
    if y >= x / 2.0 && y <= 2.0 * x && y != x {
      let d = sterbenz_sub(x, y)
      // exact subtraction: re-adding recovers y
      assert_eq(d + x == y, true)
    }
  }
  // constructed exact case: y = 1.5x
  let d = sterbenz_sub(3.0, 4.5)
  assert_eq(d == 1.5, true)
}

///|
test "Kahan and naive diverge on mixed-scale stream (T-NAIVE-GAP)" {
  // powers of two spanning 80 binades: naive addition must lose the tiny
  // terms against a large partial sum; Kahan compensates
  let rng = LCG::new(5)
  let stream : Array[Double] = []
  for _ in 0..<20000 {
    let e = (rng.next_u64() % 80UL).to_int() - 40
    stream.push(@math.pow(2.0, e.to_double()))
  }
  let naive = naive_sum(0.0, stream)
  let kahan = kahan_sum(0.0, stream)
  assert_eq(naive != kahan, true)
  // determinism: same stream twice -> identical compensated result
  assert_eq(kahan == kahan_sum(0.0, stream), true)
}

///|
test "fast_two_sum splits the rounding error (T-F2S)" {
  let big = @math.pow(2.0, 53.0)
  let t = fast_two_sum(big, 1.0)
  assert_eq(t.s == big, true) // rounding absorbed the 1
  assert_eq(t.e == 1.0, true) // compensation recovered it exactly
  // identity: fl(s + e) == fl(a + b)
  assert_eq(t.s + t.e == big + 1.0, true)
}
