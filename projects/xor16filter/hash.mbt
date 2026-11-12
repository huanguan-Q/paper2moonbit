///|
/// Murmur3 finalizer: scrambles a 64-bit value. Reference: xorfilter.h xor_murmur64.
pub fn murmur64(h : UInt64) -> UInt64 {
  let mut h = h
  h = h ^ (h >> 33)
  h = h * 0xff51afd7ed558ccdUL
  h = h ^ (h >> 33)
  h = h * 0xc4ceb9fe1a85ec53UL
  h = h ^ (h >> 33)
  h
}

///|
/// Rotate-left for 64-bit values. c must be in 1..=63.
pub fn rotl64(n : UInt64, c : Int32) -> UInt64 {
  (n << c) | (n >> (64 - c))
}

///|
/// Low 32 bits as a stand-in for (uint32_t) truncation.
pub fn low32(h : UInt64) -> UInt64 {
  h & 0xFFFFFFFFUL
}

///|
/// Fast modulo reduction: (hash * n) >> 32, result in 0..<n.
/// hash must already be a 32-bit value (see low32). Reference: xor_reduce.
pub fn reduce(hash : UInt64, n : Int32) -> Int32 {
  ((hash * n.to_uint64()) >> 32).to_int()
}

///|
/// splitmix64 PRNG step, state kept in a Ref. Used for seeds and test data.
pub fn splitmix64_next(seed : Ref[UInt64]) -> UInt64 {
  seed.val = seed.val + 0x9E3779B97F4A7C15UL
  let mut z = seed.val
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}
