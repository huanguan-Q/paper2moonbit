// Zipf stream generator — community-standard CMS stress distribution.
// The journal version carries no experiment tables (see BLUEPRINT deviation);
// judged by Thm 1 guarantees instead.

///|
/// Keys 1..vocab with weight ∝ 1/k^s, inverse-CDF sampling from seeded LCG.
pub fn zipf_stream(
  rng : LCG,
  s : Double,
  vocab : Int32,
  n : Int32,
) -> Array[Int32] {
  let cdf : Array[Double] = []
  let mut acc = 0.0
  let mut k = 1
  while k <= vocab {
    acc += @math.pow(1.0 / k.to_double(), s)
    cdf.push(acc)
    k += 1
  }
  let total = acc
  let out : Array[Int32] = []
  let mut i = 0
  while i < n {
    let u = rng.next_double() * total
    let mut lo = 0
    let mut hi = vocab - 1
    while lo < hi {
      let mid = (lo + hi) / 2
      if cdf[mid] < u {
        lo = mid + 1
      } else {
        hi = mid
      }
    }
    out.push(lo + 1)
    i += 1
  }
  out
}
