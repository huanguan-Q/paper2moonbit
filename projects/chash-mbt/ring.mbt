// Ranged hash family member (paper §4.2): f^V(i) = bucket whose associated
// point is closest to the item's point on the discretized unit interval.
// Each bucket carries K = points_per_bucket replicated random points.

///|
pub struct PointEntry {
  point : Int32
  bucket : Int32
}

///|
pub struct RangedHash {
  seed : UInt64
  points_per_bucket : Int32
  // sorted by point; ties impossible in practice (2^30 domain, few points)
  priv mut entries : Array[PointEntry]
  priv mut live : Array[Int32] // currently registered bucket ids
  priv mut next_bucket : Int32 // id allocator for anonymous add
}

///|
pub fn RangedHash::new(
  seed~ : UInt64,
  points_per_bucket~ : Int32,
) -> RangedHash {
  { seed, points_per_bucket, entries: [], live: [], next_bucket: 0, }
}

///|
/// Register an explicit bucket id with its replicated points.
pub fn RangedHash::add_bucket(self : RangedHash, bucket : Int32) -> Unit {
  if self.has_bucket(bucket) {
    return
  }
  let mut k = 0
  while k < self.points_per_bucket {
    let p = bucket_point(self.seed, bucket, k)
    self.insert_entry(PointEntry::{ point: p, bucket, })
    k += 1
  }
  self.live.push(bucket)
}

///|
/// Allocate the next anonymous bucket id and register it.
pub fn RangedHash::add_next_bucket(self : RangedHash) -> Int32 {
  let id = self.next_bucket
  self.next_bucket += 1
  self.add_bucket(id)
  id
}

///|
/// Remove a bucket and all its points. Returns false if not registered.
pub fn RangedHash::remove_bucket(self : RangedHash, bucket : Int32) -> Bool {
  let kept : Array[PointEntry] = []
  let mut found = false
  for e in self.entries {
    if e.bucket == bucket {
      found = true
    } else {
      kept.push(e)
    }
  }
  if !found {
    return false
  }
  self.entries = kept
  let livekept : Array[Int32] = []
  for b in self.live {
    if b != bucket {
      livekept.push(b)
    }
  }
  self.live = livekept
  true
}

///|
pub fn RangedHash::has_bucket(self : RangedHash, bucket : Int32) -> Bool {
  for b in self.live {
    if b == bucket {
      return true
    }
  }
  false
}

///|
fn RangedHash::insert_entry(self : RangedHash, e : PointEntry) -> Unit {
  // sorted insertion by point
  let mut lo = 0
  let mut hi = self.entries.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if self.entries[mid].point < e.point {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  self.entries.insert(lo, e)
}

///|
/// f^V(i): the bucket whose point is closest to the item's point (§4.2).
/// Nearest point via binary search over the sorted entry list; the two
/// neighbors of the insertion position are the only candidates.
pub fn RangedHash::assign(self : RangedHash, item : Int32) -> Int32 {
  if self.entries.length() == 0 {
    abort("assign on empty view")
  }
  let x = item_point(self.seed, item)
  let n = self.entries.length()
  let mut lo = 0
  let mut hi = n
  while lo < hi {
    let mid = (lo + hi) / 2
    if self.entries[mid].point < x {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  // candidate at lo (first point >= x) and lo-1 (last point < x)
  let mut best = -1
  let mut best_dist = RING + 1
  if lo < n {
    let d = (self.entries[lo].point - x).abs()
    if d < best_dist {
      best_dist = d
      best = lo
    }
  }
  if lo > 0 {
    let d = (self.entries[lo - 1].point - x).abs()
    if d < best_dist {
      best_dist = d
      best = lo - 1
    }
  }
  self.entries[best].bucket
}

///|
/// Linear distance on the discretized unit interval (§4.2: |r_B(b) − r_I(i)|).
pub fn distance(a : Int32, b : Int32) -> Int32 {
  (a - b).abs()
}
