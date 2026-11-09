// FORMAL boundary recalibration probes (moon 0.1.20261104).
// P1: Int false contract (positive control — must FAIL)
pub fn int_false_probe(a : Int) -> Int where {
  proof_ensure: r => r == a + 1,
} {
  a
}

// P3: lambda && in .mbt contract (was: OK on .mbt path)
pub fn int_and_probe(a : Int) -> Int where {
  proof_ensure: r => r >= 0 && r <= a + 1,
} {
  if a < 0 { 0 } else { a }
}

// P5: div monotonicity (was: timeout)
pub fn div_mono_probe(c1 : Int, c2 : Int) -> Int where {
  proof_require: c1 >= 1,
  proof_require: c2 > c1,
  proof_ensure: r => r == 100000 / c2,
} {
  100000 / c2
}
