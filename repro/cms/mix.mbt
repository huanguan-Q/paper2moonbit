///| 64-bit mixing (splitmix64 finalizer). Stands in for the pairwise-independent

///|
/// hash family the paper assumes: cheap, deterministic, well-spread.
fn mix64(x : UInt64) -> UInt64 {
  let mut z = x
  z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9UL
  z = (z ^ (z >> 27)) * 0x94d049bb133111ebUL
  z ^ (z >> 31)
}

///|
/// Cell index for (key, row): each row gets an independent-looking position.
fn hash_idx(key : Int32, row : Int32, width : Int32, seed : UInt64) -> Int32 {
  let k = key.reinterpret_as_uint().to_uint64()
  let r = row.reinterpret_as_uint().to_uint64()
  let mixed = mix64(seed ^ mix64(k * 0x9e3779b97f4a7c15UL + r))
  (mixed % width.to_uint64()).to_int()
}
