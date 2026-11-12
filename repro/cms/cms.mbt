///| Count-Min Sketch: d rows of w counters, query = min over rows.

///| `total` is derived from row 0 rather than stored, so there is no mutable

///|
/// state to keep consistent across add/merge.
pub struct CMS {
  width : Int32
  depth : Int32
  seed : UInt64
  counters : Array[Array[Int32]]
}

///|
/// w = ceil(e/eps), d = ceil(ln(1/delta)) — the paper's parameter choice.
pub fn CMS::new(eps : Double, delta : Double, seed : UInt64) -> CMS {
  let w = @math.ceil(2.718281828459045 / eps).to_int()
  let d = @math.ceil(@math.ln(1.0 / delta)).to_int()
  let width = if w < 2 { 2 } else { w }
  let depth = if d < 1 { 1 } else { d }
  let counters : Array[Array[Int32]] = []
  for _ in 0..<depth {
    let row : Array[Int32] = []
    for _ in 0..<width {
      row.push(0)
    }
    counters.push(row)
  }
  { width, depth, seed, counters, }
}

///|
pub fn CMS::add(self : CMS, key : Int32, c : Int32) -> Unit {
  for i in 0..<self.depth {
    let j = hash_idx(key, i, self.width, self.seed)
    self.counters[i][j] = self.counters[i][j] + c
  }
}

///|
pub fn CMS::estimate(self : CMS, key : Int32) -> Int32 {
  let mut best = -1
  for i in 0..<self.depth {
    let j = hash_idx(key, i, self.width, self.seed)
    let v = self.counters[i][j]
    if best < 0 || v < best {
      best = v
    }
  }
  best
}

///|
/// Row 0 receives every update, so its sum is the stream length.
pub fn CMS::total(self : CMS) -> Int32 {
  let mut s = 0
  for v in self.counters[0] {
    s = s + v
  }
  s
}

///|
/// Cell-wise addition; both sketches must share width/depth/seed.
pub fn CMS::merge(self : CMS, other : CMS) -> Unit {
  for i in 0..<self.depth {
    for j in 0..<self.width {
      self.counters[i][j] = self.counters[i][j] + other.counters[i][j]
    }
  }
}
