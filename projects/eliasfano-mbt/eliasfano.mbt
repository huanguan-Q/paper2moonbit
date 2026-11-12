///|
/// Elias-Fano encoded monotone sequence (arXiv:1206.4300).
struct EliasFano {
  n : Int32
  l : Int32
  lower : BitVec
  upper : BitVec
}

///|
/// floor(log2(q)) for q >= 1; 0 for q = 0.
/// Guard l < 63: wasm shifts wrap mod 64, so q >> 64 would loop forever.
fn floor_log2(q : UInt64) -> Int32 {
  let mut l : Int32 = 0
  while l < 63 && q >> (l + 1) > 0UL {
    l += 1
  }
  l
}

///|
/// Build from a monotone (non-decreasing) sequence. Err on violations.
pub fn build(xs : Array[UInt64]) -> Result[EliasFano, String] {
  let n = xs.length()
  for i in 1..<n {
    if xs[i] < xs[i - 1] {
      return Err(
        "input not monotone: xs[\{i}]=\{xs[i]} < xs[\{i - 1}]=\{xs[i - 1]}",
      )
    }
  }
  if n == 0 {
    return Ok(EliasFano::{
      n: 0,
      l: 0,
      lower: BitVec::new_zero(0),
      upper: BitVec::new_zero(1),
    })
  }
  let u = xs[n - 1]
  let n_u = n.to_uint64()
  let l = if u >= n_u { floor_log2(u / n_u) } else { 0 }
  // lower bits: n fields of l bits
  let lower = BitVec::new_zero(n * l)
  // upper bits: for each i, a 1 at position high_i + i
  let high_last = (u >> l).to_int()
  let upper = BitVec::new_zero(high_last + n + 1)
  for i, x in xs {
    let high = (x >> l).to_int()
    upper.set_bit(high + i)
    lower.write_field(i * l, l, x & mask64(l))
  }
  Ok(EliasFano::{ n, l, lower, upper, })
}

///|
/// Convenience wrapper: build and abort the program on invalid input.
pub fn build_ok(xs : Array[UInt64]) -> EliasFano {
  match build(xs) {
    Ok(f) => f
    Err(msg) => abort("build failed: \{msg}")
  }
}

///|
pub fn EliasFano::length(self : EliasFano) -> Int32 {
  self.n
}

///|
pub fn EliasFano::lower_bits(self : EliasFano) -> Int32 {
  self.l
}

///|
/// Total encoded bits (lower + upper), the paper's space measure.
pub fn EliasFano::total_bits(self : EliasFano) -> Int32 {
  self.lower.words.length() * 64 + self.upper.words.length() * 64
}

///|
/// Random access: i-th smallest element. O(n/64) due to linear select.
pub fn EliasFano::get(self : EliasFano, i : Int32) -> UInt64 {
  if i < 0 || i >= self.n {
    abort("EliasFano::get index \{i} out of range [0, \{self.n})")
  }
  self.get_unchecked(i)
}

///|
/// Successor query: first element >= x, or None. Binary search over get.
pub fn EliasFano::next_ge(self : EliasFano, x : UInt64) -> UInt64? {
  if self.n == 0 || x > self.get_unchecked(self.n - 1) {
    return None
  }
  // lower_bound: first i with get(i) >= x
  let mut lo : Int32 = 0
  let mut hi : Int32 = self.n // invariant: get(hi) >= x
  while lo < hi {
    let mid = (lo + hi) / 2
    if self.get_unchecked(mid) >= x {
      hi = mid
    } else {
      lo = mid + 1
    }
  }
  Some(self.get_unchecked(lo))
}

///|
/// get with caller-guaranteed in-range index.
fn EliasFano::get_unchecked(self : EliasFano, i : Int32) -> UInt64 {
  let pos = self.upper.select1(i)
  let high = (pos - i).to_uint64()
  let low = self.lower.read_field(i * self.l, self.l)
  (high << self.l) | low
}
