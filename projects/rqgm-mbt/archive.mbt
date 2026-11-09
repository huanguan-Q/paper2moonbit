// Archive tree with utility evidence records (RQGM §3.2, App. F.1).
// A record carries dep: the (slot, epoch-tag) pairs of the evaluator slots it
// depends on; dep = [] means evaluator-independent (valid under every epoch).

///|
pub struct ArchiveNode {
  id : Int32
  parent : Int32 // -1 for the seed root
}

///|
pub struct Record {
  node : Int32
  dep : Array[(Int32, Int32)] // (slot id, kappa tag = slot epoch at generation)
  outcome : Int32 // binary o in {0, 1}
}

///|
pub struct Archive {
  nodes : Array[ArchiveNode]
  priv mut records : Array[Record]
  // derived per-node statistics (own records only; recomputed after erasure)
  succ : Array[Int32]
  fail : Array[Int32]
}

///|
pub fn Archive::new() -> Archive {
  let arch = { nodes: [], records: [], succ: [], fail: [], }
  // seed node 0, parent -1
  arch.nodes.push({ id: 0, parent: -1, })
  arch.succ.push(0)
  arch.fail.push(0)
  arch
}

///|
pub fn Archive::add_node(self : Archive, parent : Int32) -> Int32 {
  let id = self.nodes.length()
  self.nodes.push({ id, parent, })
  self.succ.push(0)
  self.fail.push(0)
  id
}

///|
pub fn Archive::add_record(
  self : Archive,
  node : Int32,
  dep : Array[(Int32, Int32)],
  outcome : Int32,
) -> Unit {
  self.records.push({ node, dep: dep.copy(), outcome, })
}

///|
/// Clade of node a: the subtree rooted at a (including a itself).
pub fn Archive::clade(self : Archive, a : Int32) -> Array[Int32] {
  let out = [a]
  let mut i = 0
  while i < out.length() {
    let cur = out[i]
    for node in self.nodes {
      if node.parent == cur {
        out.push(node.id)
      }
    }
    i += 1
  }
  out
}

///|
/// Pooled (successes, failures) over the clade of a — the numerator and
/// denominator of clade metaproductivity (§3.1).
pub fn Archive::clade_counts(self : Archive, a : Int32) -> (Int32, Int32) {
  let mut s = 0
  let mut f = 0
  for n in self.clade(a) {
    s += self.succ[n]
    f += self.fail[n]
  }
  (s, f)
}

///|
/// Clade metaproductivity CMP(a) = n_C_succ / (n_C_succ + n_C_fail).
/// Clades always contain at least the node itself, and the Beta(1,1) prior
/// of best-belief does not apply here: an unmeasured clade has CMP 0/0,
/// returned as 0.0 (no evidence — Thompson sampling handles it via prior).
pub fn Archive::cmp_score(self : Archive, a : Int32) -> Double {
  let (s, f) = self.clade_counts(a)
  let total = s + f
  if total == 0 {
    return 0.0
  }
  s.to_double() / total.to_double()
}

///|
/// Recompute all derived statistics from retained records (Def. F.2:
/// after erasure, no stale record may enter the statistics).
pub fn Archive::recompute(self : Archive) -> Unit {
  for i in 0..<self.nodes.length() {
    self.succ[i] = 0
    self.fail[i] = 0
  }
  for r in self.records {
    if r.outcome == 1 {
      self.succ[r.node] += 1
    } else {
      self.fail[r.node] += 1
    }
  }
}

///|
/// Selective erasure Erase_m (Def. F.2): remove every record that depends on
/// slot m and was generated under an epoch tag other than new_epoch. Records
/// with m not in dep, and records carrying the fresh tag, are retained.
/// Returns the number of removed records.
pub fn Archive::erase_slot(
  self : Archive,
  slot : Int32,
  new_epoch : Int32,
) -> Int32 {
  let kept : Array[Record] = []
  let mut removed = 0
  for r in self.records {
    let mut depends_stale = false
    for pair in r.dep {
      let (s, tag) = pair
      if s == slot && tag != new_epoch {
        depends_stale = true
      }
    }
    if depends_stale {
      removed += 1
    } else {
      kept.push(r)
    }
  }
  self.records = kept
  removed
}
