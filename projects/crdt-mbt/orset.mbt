///|
// State-based Observed-Remove Set (Shapiro et al. 2011, §3.3.5).
// The paper gives only the op-based specification (Spec 15) and leaves the
// state-based one "as an exercise"; the derivation below follows the paper's
// text: each add is tagged uniquely, remove tombstones exactly the tags
// observed at the source, and merge takes pair-union + tombstone-union while
// stripping tombstoned pairs. Consequences: concurrent add wins (Fig. 14),
// and a re-add after remove takes effect (fresh tag ∉ tombstones).

///|
pub struct ORSet {
  priv pairs : Array[(String, Int32)] // live (element, tag)
  priv tombstones : Array[(String, Int32)] // observed-removed (element, tag)
  priv mut next : Int32 // local tag generator
  priv base : Int32 // per-replica tag offset (keeps tags globally unique)
}

///|
/// `base` must differ across replicas (e.g. replica_id * 1_000_000) so that
/// concurrent adds always carry distinct tags (paper §3.3.5 uniqueness).
pub fn ORSet::new(base : Int32) -> ORSet {
  { pairs: [], tombstones: [], next: 0, base, }
}

///|
/// add(e): insert (e, fresh unique tag) — the paper's add-wins mechanism.
pub fn ORSet::add(self : ORSet, e : String) -> Unit {
  let tag = self.base + self.next
  self.next = self.next + 1
  self.pairs.push((e, tag))
}

///|
/// remove(e): tombstone every (e, tag) pair observed locally — only those
/// (§3.3.5) — and drop them from the live pairs so the local abstract state
/// reflects the removal immediately. Tags added concurrently elsewhere are
/// not observed, hence survive: add wins.
pub fn ORSet::remove(self : ORSet, e : String) -> Unit {
  let mut i = 0
  while i < self.pairs.length() {
    let (elem, tag) = self.pairs[i]
    if elem == e {
      self.tombstones.push((e, tag))
      let last = self.pairs.length() - 1
      self.pairs[i] = self.pairs[last]
      let _ = self.pairs.pop()
    } else {
      i += 1
    }
  }
}

///|
/// lookup(e) = ∃ tag. (e, tag) ∈ live pairs.
pub fn ORSet::lookup(self : ORSet, e : String) -> Bool {
  let mut found = false
  for p in self.pairs {
    let (elem, _) = p
    if elem == e {
      found = true
    }
  }
  found
}

///|
/// merge: tombstones := T1 ∪ T2; pairs := (P1 ∪ P2) \\ (T1 ∪ T2).
/// Commutative, associative, idempotent — the state-based CRDT laws.
pub fn ORSet::merge(self : ORSet, other : ORSet) -> Unit {
  for t in other.tombstones {
    if !has_pair(self.tombstones, t) {
      self.tombstones.push(t)
    }
  }
  for p in other.pairs {
    if !has_pair(self.tombstones, p) && !has_pair(self.pairs, p) {
      self.pairs.push(p)
    }
  }
  // strip locally-live pairs newly covered by tombstones
  let mut i = 0
  while i < self.pairs.length() {
    if has_pair(self.tombstones, self.pairs[i]) {
      let last = self.pairs.length() - 1
      self.pairs[i] = self.pairs[last]
      let _ = self.pairs.pop()
    } else {
      i += 1
    }
  }
}

///|
fn has_pair(xs : Array[(String, Int32)], target : (String, Int32)) -> Bool {
  let (te, tt) = target
  let mut found = false
  for p in xs {
    let (e, t) = p
    if e == te && t == tt {
      found = true
    }
  }
  found
}
