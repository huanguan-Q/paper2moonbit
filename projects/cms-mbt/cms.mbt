// Count-Min Sketch — Cormode & Muthukrishnan, J. Algorithms 55(1) 2005.
// Data structure + Update (§3) + point/range/inner-product queries (§4)
// + the community conservative-update variant (see BLUEPRINT deviation).

///|
pub struct CMS {
  w : Int32
  d : Int32
  seed : UInt64
  counts : Array[Array[Int32]] // d rows of w counters, all zero initially
}

///|
/// Given (w, d) directly (paper: w = ceil(e/eps), d = ceil(ln 1/delta)).
pub fn CMS::new(w~ : Int32, d~ : Int32, seed~ : UInt64) -> CMS {
  let rows : Array[Array[Int32]] = []
  let mut j = 0
  while j < d {
    rows.push(Array::make(w, 0))
    j += 1
  }
  { w, d, seed, counts: rows, }
}

///|
/// Given (eps, delta): w = ceil(e/eps), d = ceil(ln 1/delta) (§3).
pub fn CMS::with_params(eps~ : Double, delta~ : Double, seed~ : UInt64) -> CMS {
  let e = 2.718281828459045
  let w = (e / eps).ceil().to_int()
  let d = @math.ln(1.0 / delta).ceil().to_int()
  CMS::new(w~, d~, seed~)
}

///|
pub fn CMS::depth(self : CMS) -> Int32 {
  self.d
}

///|
pub fn CMS::width(self : CMS) -> Int32 {
  self.w
}

///|
/// Update Procedure (§3): count[j, h_j(it)] += ct for every row j.
pub fn CMS::update(self : CMS, item : Int32, c : Int32) -> Unit {
  let mut j = 0
  while j < self.d {
    let idx = row_index(self.seed, j, item, self.w)
    self.counts[j][idx] += c
    j += 1
  }
}

///|
/// Point query (§4.1): a^_i = min_j count[j, h_j(i)].
pub fn CMS::point_query(self : CMS, item : Int32) -> Int32 {
  let mut best = 2147483647
  let mut j = 0
  while j < self.d {
    let idx = row_index(self.seed, j, item, self.w)
    let v = self.counts[j][idx]
    if v < best {
      best = v
    }
    j += 1
  }
  best
}

///|
/// Sum of one row — the linear invariant behind the update procedure.
pub fn CMS::row_sum(self : CMS, j : Int32) -> Int32 {
  let mut acc = 0
  let mut k = 0
  while k < self.w {
    acc += self.counts[j][k]
    k += 1
  }
  acc
}

///|
/// Range query (§4.3, without dyadic optimization): sum of point queries.
pub fn CMS::range_query(self : CMS, l : Int32, r : Int32) -> Int32 {
  let mut acc = 0
  let mut i = l
  while i <= r {
    acc += self.point_query(i)
    i += 1
  }
  acc
}

///|
/// Inner product query (§4.2 Thm 3): (a^ . b) = min_j sum_k ca[j,k]*cb[j,k].
pub fn CMS::inner_product(a : CMS, b : CMS) -> Int32 {
  if a.w != b.w || a.d != b.d {
    abort("inner_product: sketch dimensions differ")
  }
  let mut best = 2147483647
  let mut j = 0
  while j < a.d {
    let mut acc = 0
    let mut k = 0
    while k < a.w {
      acc += a.counts[j][k] * b.counts[j][k]
      k += 1
    }
    if acc < best {
      best = acc
    }
    j += 1
  }
  best
}

///|
/// Conservative update (community variant — Estan-Varghese lineage; NOT part
/// of the 2005 journal text, see BLUEPRINT deviation): compute the current
/// estimate a^, then count[j, h_j(i)] <- max{count[j, h_j(i)], a^ + c}.
pub fn CMS::conservative_update(self : CMS, item : Int32, c : Int32) -> Unit {
  let est = self.point_query(item)
  let target = est + c
  let mut j = 0
  while j < self.d {
    let idx = row_index(self.seed, j, item, self.w)
    if self.counts[j][idx] < target {
      self.counts[j][idx] = target
    }
    j += 1
  }
}
