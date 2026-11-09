///|
// State-based grow-only Set (Shapiro et al. 2011, Specification 11).
// add-only; merge = union; states form a semilattice under ⊆.

///|
pub struct GSet {
  priv items : Array[String]
}

///|
pub fn GSet::new() -> GSet {
  { items: [], }
}

///|
/// A := A ∪ {e} (Spec 11, update).
pub fn GSet::add(self : GSet, e : String) -> Unit {
  if !self.contains(e) {
    self.items.push(e)
  }
}

///|
/// lookup(e) = e ∈ A (Spec 11, query).
pub fn GSet::lookup(self : GSet, e : String) -> Bool {
  self.contains(e)
}

///|
/// merge(S, T) = S.A ∪ T.A, in place (Spec 11).
pub fn GSet::merge(self : GSet, other : GSet) -> Unit {
  for e in other.items {
    self.add(e)
  }
}

///|
fn GSet::contains(self : GSet, e : String) -> Bool {
  let mut found = false
  for x in self.items {
    if x == e {
      found = true
    }
  }
  found
}
