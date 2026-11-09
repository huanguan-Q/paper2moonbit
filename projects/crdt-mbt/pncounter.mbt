///|
// State-based PN-Counter (Shapiro et al. 2011, Specification 7): two
// G-Counters — P for increments, N for decrements; value = ΣP − ΣN.

///|
pub struct PNCounter {
  priv p : GCounter
  priv n : GCounter
}

///|
/// Create a PN-Counter with `n` replica slots.
pub fn PNCounter::new(n : Int32) -> PNCounter {
  { p: GCounter::new(n), n: GCounter::new(n), }
}

///|
/// P[g] := P[g] + 1 (Spec 7, update increment).
pub fn PNCounter::increment(self : PNCounter, replica : Int32) -> Unit {
  self.p.increment(replica)
}

///|
/// N[g] := N[g] + 1 (Spec 7, update decrement).
pub fn PNCounter::decrement(self : PNCounter, replica : Int32) -> Unit {
  self.n.increment(replica)
}

///|
/// value() = ΣP[i] − ΣN[i] (Spec 7, query).
pub fn PNCounter::value(self : PNCounter) -> Int32 {
  self.p.value() - self.n.value()
}

///|
/// merge: per-entry max on both vectors, in place (Spec 7).
pub fn PNCounter::merge(self : PNCounter, other : PNCounter) -> Unit {
  self.p.merge(other.p)
  self.n.merge(other.n)
}
