// LogLog estimator (paper §2) + SuperLogLog variant (§5 Truncation Rule).
// E = alpha_m * m * 2^(mean of registers), alpha_m replaced by alpha_inf =
// e^-gamma * sqrt(2)/2 ~= 0.39701 — the paper explicitly blesses this for
// m >= 64 ("without much detectable bias").

///|
const ALPHA_INF : Double = 0.39701

///|
const REG_BITS : Int32 = 5 // "small bytes" of 5 bits (§4)

///|
pub struct LogLog {
  k : Int32 // m = 2^k
  seed : UInt64
  regs : PackedRegs
}

///|
pub fn LogLog::new(k~ : Int32, seed~ : UInt64) -> LogLog {
  let m = 1 << k
  { k, seed, regs: PackedRegs::new(m, REG_BITS), }
}

///|
/// Register count m = 2^k.
pub fn LogLog::register_count(self : LogLog) -> Int32 {
  1 << self.k
}

///|
/// Storage in bytes — paper §4: 1024 x 5 bits = 640 bytes.
pub fn LogLog::register_bytes(self : LogLog) -> Int32 {
  self.regs.byte_size()
}

///|
/// Raw register value (for invariant checks and merge).
pub fn LogLog::raw_register(self : LogLog, i : Int32) -> Int32 {
  self.regs.get(i)
}

///|
/// Algorithm LogLog (§2): bucket = first k bits, register = max rho of
/// the remaining bits, capped to the 5-bit Restriction domain.
pub fn LogLog::add(self : LogLog, item : Int32) -> Unit {
  let h = mix64(self.seed, item)
  let bucket = bucket_of(h, self.k)
  let r = rho(payload_of(h, self.k))
  let cur = self.regs.get(bucket)
  if r > cur {
    self.regs.put(bucket, cap_reg(r))
  }
}

///|
/// Estimate E = alpha_inf * m * 2^(mean of registers) (§2 Eq. 1).
pub fn LogLog::estimate(self : LogLog) -> Double {
  let m = self.register_count()
  let mut sum = 0
  for i in 0..<m {
    sum += self.regs.get(i)
  }
  let mean = sum.to_double() / m.to_double()
  ALPHA_INF * m.to_double() * @math.pow(2.0, mean)
}

///|
/// SuperLogLog (§5 Truncation Rule): retain the m0 = theta0*m smallest
/// register values, estimate alpha_m * m0 * 2^(mean of retained).
/// Counting sort over the 5-bit domain (values 0..31).
pub fn LogLog::superloglog_estimate(self : LogLog) -> Double {
  let m = self.register_count()
  let m0 = m * 7 / 10 // theta0 = 0.7 (paper: near-optimal)
  // counting sort of register values
  let hist = Array::make(32, 0)
  for i in 0..<m {
    let v = self.regs.get(i)
    hist[v] += 1
  }
  // mean of the m0 smallest values
  let mut taken = 0
  let mut sum = 0
  let mut v = 0
  while v < 32 && taken < m0 {
    let take = if hist[v] < m0 - taken { hist[v] } else { m0 - taken }
    sum += take * v
    taken += take
    v += 1
  }
  let mean = sum.to_double() / taken.to_double()
  ALPHA_INF * taken.to_double() * @math.pow(2.0, mean)
}

///|
/// max-merge (§6): register-wise maximum — distributed processors sharing
/// the same hash merge their tables by taking maxima.
pub fn LogLog::merge(self : LogLog, other : LogLog) -> Unit {
  let m = self.register_count()
  for i in 0..<m {
    let merged = if self.regs.get(i) >= other.regs.get(i) {
      self.regs.get(i)
    } else {
      other.regs.get(i)
    }
    self.regs.put(i, merged)
  }
}
