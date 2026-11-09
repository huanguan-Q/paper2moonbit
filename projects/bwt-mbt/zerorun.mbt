// Zero-run coding of the MTF output R (paper §5 variant): "we can take
// advantage of this effect by representing each run of zeroes by a code
// indicating the length of the run."
// Encoding over Int streams: a run of k>=1 zeros becomes the marker pair
// (0, k); every nonzero value passes through unchanged. Markers cannot be
// confused with data because a literal zero is never emitted alone.

///|
const RUN_MARKER : Int32 = 0

///|
pub fn zero_run_encode(r : Array[Int32]) -> Array[Int32] {
  let out : Array[Int32] = []
  let n = r.length()
  let mut i = 0
  while i < n {
    if r[i] == 0 {
      let mut k = 0
      while i < n && r[i] == 0 {
        k += 1
        i += 1
      }
      out.push(RUN_MARKER)
      out.push(k)
    } else {
      out.push(r[i])
      i += 1
    }
  }
  out
}

///|
pub fn zero_run_decode(z : Array[Int32]) -> Array[Int32] {
  let out : Array[Int32] = []
  let n = z.length()
  let mut i = 0
  while i < n {
    if z[i] == RUN_MARKER && i + 1 < n {
      let k = z[i + 1]
      let mut c = 0
      while c < k {
        out.push(0)
        c += 1
      }
      i += 2
    } else {
      out.push(z[i])
      i += 1
    }
  }
  out
}
