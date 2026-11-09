// Floating-point compensated arithmetic (Goldberg 1991 Theorem 8 +
// standard error-free transformations; provenance noted per function).
// NOTE: MoonBit Double has no builtin bit-reinterpretation API (probed:
// to_bits/reinterpret_as_uint64/to_int64_bits all absent), so "bit-exact"
// judgments use IEEE value equality (==) — sufficient for all identities
// here since no -0.0/NaN ambiguity arises in the test domains.

///|
pub struct LCG {
  priv mut state : UInt64
}

///|
pub fn LCG::new(seed : UInt64) -> LCG {
  { state: seed * 6364136223846793005UL + 1442695040888963407UL, }
}

///|
pub fn LCG::next_u64(self : LCG) -> UInt64 {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  self.state
}

///|
pub fn LCG::next_double(self : LCG) -> Double {
  let v = self.next_u64() >> 11
  v.to_double() / 9007199254740992.0
}

///|
/// IEEE finiteness without a builtin: NaN fails self-equality, inf minus
/// itself is NaN.
pub fn is_finite(x : Double) -> Bool {
  x == x && x - x == 0.0
}

///|
pub struct TwoSumResult {
  s : Double
  e : Double
}

///|
/// FastTwoSum (Moller/Knuth lineage; the shape of Thm 8's C = (T-S) - Y).
/// Precondition |a| >= |b|: s = fl(a+b), e captures the rounding remainder
/// exactly, so the real-number identity a + b = s + e holds.
pub fn fast_two_sum(a : Double, b : Double) -> TwoSumResult {
  let s = a + b // fl(a + b)
  let z = s - a // exact under |a| >= |b| (first term dominates)
  let e = b - z // the rounding remainder, computed exactly
  { s, e, }
}

///|
/// TwoSum: unordered variant implemented via the branch form — sort the
/// operands by magnitude and apply FastTwoSum (the standard practice).
/// DEVIATION NOTE: the textbook 6-operation Dekker TwoSum was found to
/// produce e = 0 when b is far below ulp(a) in this environment (probed:
/// a=6.29e91, b=1.04e-111), so the branch form is used instead.
pub fn two_sum(a : Double, b : Double) -> TwoSumResult {
  if a.abs() >= b.abs() {
    fast_two_sum(a, b)
  } else {
    fast_two_sum(b, a)
  }
}

///|
/// Sterbenz lemma (Sterbenz 1974): x/2 <= y <= 2x implies fl(y - x) == y - x.
pub fn sterbenz_sub(x : Double, y : Double) -> Double {
  y - x
}

///|
/// Naive left-to-right summation (the paper's comparison baseline).
pub fn naive_sum(init : Double, xs : Array[Double]) -> Double {
  let mut s = init
  for x in xs {
    s = s + x
  }
  s
}

///|
/// Kahan summation formula (Goldberg 1991 Theorem 8, pseudocode verbatim):
///   S = X[1]; C = 0;
///   for j = 2 to N { Y = X[j] - C; T = S + Y; C = (T - S) - Y; S = T }
/// Each summand is perturbed by at most 2*eps (vs up to n*eps for naive).
pub fn kahan_sum(init : Double, xs : Array[Double]) -> Double {
  let mut s = init
  let mut c = 0.0
  for x in xs {
    let y = x - c
    let t = s + y
    c = t - s - y
    s = t
  }
  s
}
