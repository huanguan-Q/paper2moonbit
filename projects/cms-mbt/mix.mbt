// Row hash family member (paper §3: d pairwise-independent hashes h_j):
// splitmix-style mixing with a per-row seed, scaled into the row width.

///|
/// splitmix64 finalizer for (seed, row, item).
pub fn mix64(seed : UInt64, row : Int32, item : Int32) -> UInt64 {
  let mut z = seed ^
    (row.to_uint64() * 0x9E3779B97F4A7C15UL) ^
    (item.to_uint64() * 0xD6E8FEB86659FD93UL)
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
/// Scale a mixed word into a row index [0, w). Top 30 bits then modulo —
/// the FORMAL-proved scaling bound (x % w in [0, w) for x >= 0) applies.
pub fn scale_index(word : UInt64, w : Int32) -> Int32 {
  let x = (word >> 34).to_int() // < 2^30, nonnegative
  x % w
}

///|
/// Row index h_j(item) for row j of the sketch with base seed.
pub fn row_index(seed : UInt64, row : Int32, item : Int32, w : Int32) -> Int32 {
  scale_index(mix64(seed, row, item), w)
}
