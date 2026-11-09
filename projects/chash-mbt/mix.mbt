// Hash-family member: splitmix-style mixing (r_B / r_I of paper §4.2) and
// unit-interval scaling. A fixed seed picks one function from the family;
// the paper requires log(C)-way independence across family members, which
// fixed-seed tests satisfy trivially (one member at a time).

///|
const RING : Int32 = 1073741824 // 2^30

///|
/// splitmix64 finalizer — deterministic point hash for a (seed, tag) pair.
pub fn mix64(seed : UInt64, tag : UInt64) -> UInt64 {
  let mut z = seed ^ (tag * 0x9E3779B97F4A7C15UL)
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
/// Scale a mixed word into the discretized unit interval [0, RING).
pub fn scale_point(word : UInt64) -> Int32 {
  let scaled = (word >> 34).to_int() // top 30 bits
  scaled % RING
}

///|
/// Bucket point: seed s, bucket id b, replica index k.
pub fn bucket_point(seed : UInt64, bucket : Int32, k : Int32) -> Int32 {
  scale_point(mix64(seed, (bucket.to_uint64() << 32) | k.to_uint64()))
}

///|
/// Item point: seed s, item id i.
pub fn item_point(seed : UInt64, item : Int32) -> Int32 {
  scale_point(mix64(seed, 0x8000000000000000UL | item.to_uint64()))
}
