///|
// HyperLogLog runtime core (RUNTIME-VERIFIED layer).
// Registers use FixedArray; the register update composes the formally
// verified `update_reg`. The estimator uses Double + @math.ln (degraded
// domain per CAPT capability table — verified by paper-criterion tests).

///|
/// Runtime rho for UInt64 remainder bits (LSB-first scan, see BLUEPRINT).
fn rho_u64(w : UInt64, bits : Int) -> Int {
  let mut result = bits + 1
  let mut x = w
  let mut i = 1
  while i <= bits && result == bits + 1 {
    if x % 2UL == 1UL {
      result = i
    } else {
      x = x / 2UL
      i += 1
    }
  }
  result
}

///|
pub struct HLL {
  priv p : Int // registers indexed by low p bits; m = 2^p
  priv m : Int
  priv registers : FixedArray[Int]
  priv alpha_m : Double
}

///|
/// Create a HyperLogLog with m = 2^p registers (paper recommends p in 4..=16).
pub fn HLL::new(p : Int) -> HLL {
  let m = 1 << p // p <= 16, no overflow
  // alpha_m = 0.7213 / (1 + 1.079/m)  (paper Section 4)
  let alpha = 0.7213 / (1.0 + 1.079 / m.to_double())
  {
    p,
    m,
    registers: FixedArray::make(m, 0),
    alpha_m: alpha,
  }
}

///|
pub fn HLL::register_value(self : HLL, j : Int) -> Int {
  self.registers[j]
}

///|
/// Feed one 64-bit hash into the sketch. Low p bits pick the register,
/// remaining bits update it via the verified monotone update rule.
pub fn HLL::add(self : HLL, hash : UInt64) -> Unit {
  let mask = (1UL << self.p) - 1UL
  let j = (hash & mask).to_int()
  let w = hash >> self.p
  let r = rho_u64(w, 64 - self.p)
  // verified contract: 0 <= prev <= bits+1, 1 <= v <= bits+1
  self.registers[j] = update_reg(self.registers[j], r, 64 - self.p)
}

///|
/// Cardinality estimate (paper Section 4): raw = alpha_m * m^2 / sum(2^-M[j]);
/// small-range correction switches to linear counting m*ln(m/V).
pub fn HLL::count(self : HLL) -> Double {
  let mut sum : Double = 0.0
  let mut empty : Int = 0
  for j in 0..<self.m {
    let v = self.registers[j]
    sum += pow2neg(v)
    if v == 0 {
      empty += 1
    }
  }
  let raw = self.alpha_m * self.m.to_double() * self.m.to_double() / sum
  if raw <= 2.5 * self.m.to_double() && empty > 0 {
    // linear counting: m * ln(m/V)
    self.m.to_double() * @math.ln(self.m.to_double() / empty.to_double())
  } else {
    raw
  }
}

///|
/// 2^(-v) for v >= 1 without @math.pow (plain repeated halving).
fn pow2neg(v : Int) -> Double {
  let mut r = 1.0
  for _ in 0..<v {
    r = r / 2.0
  }
  r
}

///|
pub fn HLL::num_registers(self : HLL) -> Int {
  self.m
}
