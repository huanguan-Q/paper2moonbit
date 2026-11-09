// Hash layer: splitmix-style mixing; rho = position of first 1-bit from the
// left (paper §2: rho(1..)=1, rho(001..)=3); bucket = top k bits of the hash.

///|
/// splitmix64 finalizer for (seed, item).
pub fn mix64(seed : UInt64, item : Int32) -> UInt64 {
  let mut z = seed ^ (item.to_uint64() * 0x9E3779B97F4A7C15UL)
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
const TOP_BIT : UInt64 = 0x8000000000000000UL

///|
/// rho of the payload bits: rank of the first 1-bit from the left, 1-indexed.
/// Payload 0 (all bits zero) returns 64 — absorbed by register capping.
pub fn rho(payload : UInt64) -> Int32 {
  if payload == 0UL {
    64
  } else {
    let mut lz = 0
    let mut x = payload
    while (x & TOP_BIT) == 0UL {
      x = x << 1
      lz += 1
    }
    lz + 1
  }
}

///|
/// Bucket index from the top k bits of the hash (paper: first k bits select
/// the bucket among m = 2^k).
pub fn bucket_of(h : UInt64, k : Int32) -> Int32 {
  (h >> (64 - k)).to_int()
}

///|
/// Payload bits: the hash with its top k bits shifted away.
pub fn payload_of(h : UInt64, k : Int32) -> UInt64 {
  h << k
}
