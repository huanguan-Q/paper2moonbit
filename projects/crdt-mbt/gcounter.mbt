///|
// State-based increment-only counter (Shapiro et al. 2011, Specification 6).
// Payload: one Int entry per replica; merge takes per-entry max; states form
// a monotonic semilattice, so any merge order converges (paper §3.1.2).

///|
pub struct GCounter {
  priv vec : FixedArray[Int32]
}

///|
/// Create a counter with `n` replica slots (n >= 1; paper assumes the set of
/// replicas is known and fixed). All entries start at 0.
pub fn GCounter::new(n : Int32) -> GCounter {
  let size = if n < 1 { 1 } else { n }
  { vec: FixedArray::make(size, 0), }
}

///|
/// Number of replica slots (for tests and tooling).
pub fn GCounter::size(self : GCounter) -> Int32 {
  self.vec.length()
}

///|
/// Replica `g` originates one increment: P[g] := P[g] + 1 (Spec 6, update).
pub fn GCounter::increment(self : GCounter, replica : Int32) -> Unit {
  let g = if replica < 0 || replica >= self.vec.length() { 0 } else { replica }
  self.vec[g] = self.vec[g] + 1
}

///|
/// value() = Σ P[i] (Spec 6, query).
pub fn GCounter::value(self : GCounter) -> Int32 {
  let mut sum = 0
  for i in 0..<self.vec.length() {
    sum = sum + self.vec[i]
  }
  sum
}

///|
/// merge(X, Y): Z.P[i] = max(X.P[i], Y.P[i]) — applied in place (Spec 6).
pub fn GCounter::merge(self : GCounter, other : GCounter) -> Unit {
  let n = if self.vec.length() < other.vec.length() {
    self.vec.length()
  } else {
    other.vec.length()
  }
  for i in 0..<n {
    let a = self.vec[i]
    let b = other.vec[i]
    if b > a {
      self.vec[i] = b
    }
  }
}

///|
/// compare(X, Y): ∀i, X.P[i] <= Y.P[i] (Spec 6; the semilattice order).
pub fn GCounter::leq(self : GCounter, other : GCounter) -> Bool {
  let n = if self.vec.length() < other.vec.length() {
    self.vec.length()
  } else {
    other.vec.length()
  }
  let mut all = true
  for i in 0..<n {
    if self.vec[i] > other.vec[i] {
      all = false
    }
  }
  all
}
