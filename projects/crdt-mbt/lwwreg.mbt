///|
// State-based Last-Writer-Wins Register (Shapiro et al. 2011, Spec 8).
// Payload (x, t); timestamps unique, totally ordered, consistent with
// causality (paper §3.2.1). merge keeps the maximal timestamp; a tie
// (R.t <= R'.t) resolves to the right argument per the specification.

///|
pub struct LWWReg {
  priv mut t : Int32
  priv mut v : Int32
}

///|
/// Initial state (⊥, 0): value 0 at timestamp 0.
pub fn LWWReg::new() -> LWWReg {
  { t: 0, v: 0, }
}

///|
/// assign(w): x, t := w, now() — the caller supplies the logical timestamp,
/// which must be consistent with causality (Spec 8, update).
pub fn LWWReg::assign(self : LWWReg, w : Int32, ts : Int32) -> Unit {
  self.v = w
  self.t = ts
}

///|
/// value() returns the current register content (Spec 8, query).
pub fn LWWReg::value(self : LWWReg) -> Int32 {
  self.v
}

///|
/// The winning timestamp (exposed for convergence checks).
pub fn LWWReg::timestamp(self : LWWReg) -> Int32 {
  self.t
}

///|
/// merge(R, R'): keep the right argument's state iff R.t <= R'.t (Spec 8).
pub fn LWWReg::merge(self : LWWReg, other : LWWReg) -> Unit {
  if self.t <= other.t {
    self.v = other.v
    self.t = other.t
  }
}
