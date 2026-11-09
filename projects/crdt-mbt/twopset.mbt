///|
// State-based Two-Phase Set (Shapiro et al. 2011, Specification 12):
// a G-Set of adds plus a tombstone G-Set of removes. A removed element can
// never be added again (lookup = e ∈ A ∧ e ∉ R).

///|
pub struct TwoPSet {
  priv added : Array[String]
  priv removed : Array[String]
}

///|
pub fn TwoPSet::new() -> TwoPSet {
  { added: [], removed: [], }
}

///|
/// A := A ∪ {e} (Spec 12, update add — no precondition). Note: re-adding a
/// tombstoned element has no visible effect, per the 2P-Set semantics.
pub fn TwoPSet::add(self : TwoPSet, e : String) -> Unit {
  if !self.has_added(e) {
    self.added.push(e)
  }
}

///|
/// The paper's source precondition for remove, exposed as a query so callers
/// can respect Spec 12's `pre lookup(e)` explicitly.
pub fn TwoPSet::can_remove(self : TwoPSet, e : String) -> Bool {
  self.lookup(e)
}

///|
/// R := R ∪ {e}, enabled only if lookup(e) (Spec 12, update remove).
pub fn TwoPSet::remove(self : TwoPSet, e : String) -> Unit {
  if self.lookup(e) {
    if !self.has_removed(e) {
      self.removed.push(e)
    }
  }
}

///|
/// lookup(e) = e ∈ A ∧ e ∉ R (Spec 12, query).
pub fn TwoPSet::lookup(self : TwoPSet, e : String) -> Bool {
  self.has_added(e) && !self.has_removed(e)
}

///|
/// merge: union of both sets, in place (Spec 12).
pub fn TwoPSet::merge(self : TwoPSet, other : TwoPSet) -> Unit {
  for e in other.added {
    self.add(e)
  }
  for e in other.removed {
    if !self.has_removed(e) {
      self.removed.push(e)
    }
  }
}

///|
fn TwoPSet::has_added(self : TwoPSet, e : String) -> Bool {
  let mut found = false
  for x in self.added {
    if x == e {
      found = true
    }
  }
  found
}

///|
fn TwoPSet::has_removed(self : TwoPSet, e : String) -> Bool {
  let mut found = false
  for x in self.removed {
    if x == e {
      found = true
    }
  }
  found
}
