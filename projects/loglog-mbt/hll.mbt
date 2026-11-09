// HyperLogLog (Flajolet et al. 2007) — compact re-implementation of the
// round-6 verified recipe, with 6-bit packed registers, for the family
// comparison of this round (SE 1.04/sqrt(m) vs LogLog 1.30/sqrt(m)).

///|
const HLL_BITS : Int32 = 6

///|
pub struct HLL {
  k : Int32
  seed : UInt64
  regs : PackedRegs
}

///|
pub fn HLL::new(k~ : Int32, seed~ : UInt64) -> HLL {
  let m = 1 << k
  { k, seed, regs: PackedRegs::new(m, HLL_BITS), }
}

///|
pub fn HLL::register_count(self : HLL) -> Int32 {
  1 << self.k
}

///|
pub fn HLL::register_bytes(self : HLL) -> Int32 {
  self.regs.byte_size()
}

///|
/// alpha_m for the harmonic-mean estimator (HLL 2007 §3.1 constants).
fn hll_alpha(m : Int32) -> Double {
  if m == 16 {
    0.673
  } else if m == 32 {
    0.697
  } else if m == 64 {
    0.709
  } else if m == 128 {
    0.7297
  } else {
    0.7213 / (1.0 + 1.079 / m.to_double())
  }
}

///|
pub fn HLL::add(self : HLL, item : Int32) -> Unit {
  let h = mix64(self.seed, item)
  let bucket = bucket_of(h, self.k)
  let r = rho(payload_of(h, self.k))
  let cur = self.regs.get(bucket)
  if r > cur && r <= 63 {
    self.regs.put(bucket, r)
  }
}

///|
/// HLL estimate with the small-range linear-counting correction (2007 §4).
pub fn HLL::estimate(self : HLL) -> Double {
  let m = self.register_count()
  let alpha = hll_alpha(m)
  let mut sum = 0.0
  let mut zeros = 0
  for i in 0..<m {
    let v = self.regs.get(i)
    sum += @math.pow(2.0, -v.to_double())
    if v == 0 {
      zeros += 1
    }
  }
  let raw = alpha * m.to_double() * m.to_double() / sum
  if raw <= 2.5 * m.to_double() && zeros > 0 {
    // small-range correction: linear counting
    m.to_double() * @math.ln(m.to_double() / zeros.to_double())
  } else {
    raw
  }
}
