// Bit-packed register table ("small bytes", paper §4-5): width-configurable
// (LogLog/SuperLogLog: 5 bits; HyperLogLog: 6 bits). Words stored as UInt64
// for arithmetic; registers may span word boundaries (e.g. 5-bit register at
// offset 60). byte_size reports the theoretical packed size used by the
// paper's accounting (the in-memory word-aligned table is word-granular).

///|
const FULL : UInt64 = 0xFFFFFFFFFFFFFFFFUL

///|
pub struct PackedRegs {
  m : Int32
  bits : Int32
  words : FixedArray[UInt64]
}

///|
pub fn PackedRegs::new(m : Int32, bits : Int32) -> PackedRegs {
  let total = m * bits
  let nwords = (total + 63) / 64
  { m, bits, words: FixedArray::make(nwords, 0UL), }
}

///|
/// Total memory in bytes — the paper's storage accounting
/// (§4: 1024 registers of 5 bits = 640 bytes).
pub fn PackedRegs::byte_size(self : PackedRegs) -> Int32 {
  (self.m * self.bits + 7) / 8
}

///|
pub fn PackedRegs::get(self : PackedRegs, i : Int32) -> Int32 {
  let lo = i * self.bits
  let wi = lo / 64
  let off = lo % 64
  let room = 64 - off
  let mask = (1UL << self.bits) - 1UL
  if self.bits <= room {
    ((self.words[wi] >> off) & mask).to_int()
  } else {
    let spill = self.bits - room
    let hi = self.words[wi + 1] & ((1UL << spill) - 1UL)
    let v = ((self.words[wi] >> off) & mask) | (hi << room)
    v.to_int()
  }
}

///|
pub fn PackedRegs::put(self : PackedRegs, i : Int32, v : Int32) -> Unit {
  let lo = i * self.bits
  let wi = lo / 64
  let off = lo % 64
  let room = 64 - off
  let mask = (1UL << self.bits) - 1UL
  let uv = v.to_uint64()
  if self.bits <= room {
    let cleared = self.words[wi] & (FULL ^ (mask << off))
    self.words[wi] = cleared | ((uv & mask) << off)
  } else {
    let spill = self.bits - room
    let lo_mask = (1UL << room) - 1UL
    let cleared_lo = self.words[wi] & (FULL ^ (mask << off))
    self.words[wi] = cleared_lo | ((uv & lo_mask) << off)
    let hi_mask = (1UL << spill) - 1UL
    let cleared_hi = self.words[wi + 1] & (FULL ^ hi_mask)
    self.words[wi + 1] = cleared_hi | ((uv >> room) & hi_mask)
  }
}

///|
/// Restriction Rule (§4-5): 5-bit register domain cap. FORMAL contract.
pub fn cap_reg(
  v : Int32,
) -> Int32 where {
  proof_require: v >= 0,
  proof_ensure: r => r >= 0 && r <= 31,
} {
  if v < 31 {
    v
  } else {
    31
  }
}
