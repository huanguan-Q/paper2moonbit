///| Skewed stream generator: quadratic bias toward low keys, which is the

///|
/// workload shape that makes a sketch's error bound meaningful.
pub fn gen_skewed(rng : LCG, n : Int32, keys : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  for _ in 0..<n {
    let u = (rng.next_u64() % 1000000UL).to_double() / 1000000.0
    let idx = (u * u * keys.to_double()).to_int()
    out.push(if idx >= keys { keys - 1 } else { idx })
  }
  out
}
