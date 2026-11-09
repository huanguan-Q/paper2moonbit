///|
/// Demo: build a roaring bitmap over sparse 32-bit values and probe it.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let bm = @roaring.Roaring::new()
  // dense range in one container + sparse high keys
  for v in 1000U..<2000U {
    bm.add(v)
  }
  for hi in [0x0001U, 0x00FFU, 0xABCDU] {
    bm.add((hi << 16) | 42U)
  }
  let mut dense_hits = 0
  for v in 1000U..<2000U {
    if bm.contains(v) {
      dense_hits += 1
    }
  }
  println("dense range hits: \{dense_hits}/1000")
  println("sparse keys present: \{bm.contains(0x0001002AU)}, \{bm.contains(0xABCD002AU)}")
  println("negative probes: \{bm.contains(2000U)}, \{bm.contains(0xFFFE002AU)}")
}
