// Skip lists — Pugh, CACM 33(6) 1990. Figures 2/4/5 translated line by line.
// FORMAL contract on cap_level (Z3): the random level never escapes [1, max].
// NIL sentinel: a shared node whose key exceeds every legal key (paper
// initialization semantics); its forward pointers are never followed.

///|
/// Random level from a run of zero bits (paper: for p = 1/2 the level is
/// "easy to generate from a stream of random bits"). FORMAL contract: the
/// result stays in [1, max_level].
pub fn cap_level(
  run : Int32,
  max_level : Int32,
) -> Int32 where {
  proof_require: run >= 0,
  proof_require: max_level >= 1,
  proof_ensure: r => r >= 1 && r <= max_level,
} {
  if run < max_level - 1 {
    run + 1
  } else {
    max_level
  }
}

///|
/// Fig. 5 randomLevel for arbitrary p: lvl := 1; while random() < p && lvl < MaxLevel.
pub fn random_level(rng : LCG, p : Double, max_level : Int32) -> Int32 {
  if p == 0.5 {
    // bit-stream path: run of leading zeros = number of coin flips before
    // the first head; level = cap_level(run) — same law as the Fig. 5 loop
    let mut run = 0
    let mut w = rng.next_u64()
    while (w & 1UL) == 0UL && run < max_level - 1 {
      run += 1
      w = w >> 1
    }
    cap_level(run, max_level)
  } else {
    let mut lvl = 1
    while rng.next_double() < p && lvl < max_level {
      lvl += 1
    }
    lvl
  }
}

///|
/// NIL sentinel key: strictly greater than every legal key.
const NIL_KEY : Int32 = 2147483647

///|
pub struct Node {
  id : Int32 // unique within a list; NIL = -1, header = 0 (reference identity)
  key : Int32
  priv mut value : Int32
  forward : Array[Node] // forward[i] = next node at level i+1
}

///|
pub struct SkipList {
  header : Node
  nil_node : Node
  priv mut level : Int32 // current maximum level (paper: starts at 1)
  priv mut sz : Int32
  priv mut comparisons : Int32 // last search path comparison count
  priv mut next_id : Int32 // node id allocator (reference identity via id)
  p : Double
  max_level : Int32
  rng : LCG
}

///|
/// Initialization (paper §Search Algorithm): level := 1, all header forward
/// pointers point to NIL.
pub fn SkipList::new(
  max_level : Int32,
  p~ : Double = 0.5,
  seed~ : UInt64 = 1UL,
) -> SkipList {
  let nil_node = Node::{ id: -1, key: NIL_KEY, value: 0, forward: [], }
  let header = Node::{
    id: 0,
    key: -1,
    value: 0,
    forward: Array::make(max_level + 1, nil_node),
  }
  {
    header,
    nil_node,
    level: 1,
    sz: 0,
    comparisons: 0,
    next_id: 1,
    p,
    max_level,
    rng: LCG::new(seed),
  }
}

///|
pub fn SkipList::size(self : SkipList) -> Int32 {
  self.sz
}

///|
pub fn SkipList::current_level(self : SkipList) -> Int32 {
  self.level
}

///|
pub fn SkipList::last_comparisons(self : SkipList) -> Int32 {
  self.comparisons
}

///|
/// Fig. 2 Search. Returns whether the key is present; comparison count
/// recorded for the T-COST paper judgment.
pub fn SkipList::search(self : SkipList, search_key : Int32) -> Bool {
  self.comparisons = 0
  let mut x = self.header
  let mut i = self.level
  while i >= 1 {
    while x.forward[i - 1].key < search_key {
      self.comparisons += 1
      x = x.forward[i - 1]
    }
    self.comparisons += 1
    i -= 1
  }
  x = x.forward[0]
  self.comparisons += 1
  x.key == search_key
}

///|
/// Fig. 2 search returning the stored value of an existing key.
pub fn SkipList::get(self : SkipList, key : Int32) -> Int32 {
  let mut x = self.header
  let mut i = self.level
  while i >= 1 {
    while x.forward[i - 1].key < key {
      x = x.forward[i - 1]
    }
    i -= 1
  }
  x = x.forward[0]
  if x.key == key {
    x.value
  } else {
    -1
  }
}

///|
/// Fig. 4 Insert: duplicate key updates value; a new node whose level
/// exceeds the list level raises list->level and fills update with header.
pub fn SkipList::insert(
  self : SkipList,
  search_key : Int32,
  new_value : Int32,
) -> Unit {
  let update = Array::make(self.max_level + 1, self.header)
  let mut x = self.header
  let mut i = self.level
  while i >= 1 {
    while x.forward[i - 1].key < search_key {
      x = x.forward[i - 1]
    }
    update[i] = x
    i -= 1
  }
  x = x.forward[0]
  if x.key == search_key {
    x.value = new_value
    return
  }
  let lvl = random_level(self.rng, self.p, self.max_level)
  let mut eff = lvl
  if lvl > self.level {
    // paper: for i := list->level+1 to lvl do update[i] := list->header
    let mut j = self.level + 1
    while j <= lvl {
      update[j] = self.header
      j += 1
    }
    self.level = lvl
    eff = lvl
  }
  let node = Node::{
    id: self.next_id,
    key: search_key,
    value: new_value,
    forward: Array::make(eff, self.nil_node),
  }
  self.next_id += 1
  let mut k = 1
  while k <= eff {
    node.forward[k - 1] = update[k].forward[k - 1]
    update[k].forward[k - 1] = node
    k += 1
  }
  self.sz += 1
}

///|
/// Fig. 4 Delete: splice out, then shrink list->level while the top is empty.
pub fn SkipList::delete(self : SkipList, search_key : Int32) -> Bool {
  let update = Array::make(self.max_level + 1, self.header)
  let mut x = self.header
  let mut i = self.level
  while i >= 1 {
    while x.forward[i - 1].key < search_key {
      x = x.forward[i - 1]
    }
    update[i] = x
    i -= 1
  }
  x = x.forward[0]
  if x.key != search_key {
    return false
  }
  let mut k = 1
  while k <= self.level {
    if update[k].forward[k - 1].id != x.id {
      break
    }
    update[k].forward[k - 1] = x.forward[k - 1]
    k += 1
  }
  self.sz -= 1
  while self.level > 1 &&
        self.header.forward[self.level - 1].id == self.nil_node.id {
    self.level = self.level - 1
  }
  true
}

///|
/// Level-1 chain keys (ascending) — oracle comparison and invariant checks.
pub fn SkipList::to_level1_keys(self : SkipList) -> Array[Int32] {
  let out : Array[Int32] = []
  let mut x = self.header.forward[0]
  while x.id != self.nil_node.id {
    out.push(x.key)
    x = x.forward[0]
  }
  out
}

///|
/// Structural invariants: level-1 strictly ascending; every higher chain is
/// a subsequence of the one below it.
pub fn SkipList::check_invariants(self : SkipList) -> Bool {
  // strict ascending at level 1
  let keys = self.to_level1_keys()
  let n = keys.length()
  let mut i = 1
  while i < n {
    if keys[i - 1] >= keys[i] {
      return false
    }
    i += 1
  }
  // each level's chain is a subsequence of the level below
  let mut lvl = 2
  while lvl <= self.level {
    let mut lower = self.header.forward[lvl - 2]
    let mut upper = self.header.forward[lvl - 1]
    while upper.id != self.nil_node.id {
      // advance lower until it matches upper
      while lower.id != self.nil_node.id && lower.id != upper.id {
        lower = lower.forward[lvl - 2]
      }
      if lower.id != upper.id {
        return false
      }
      upper = upper.forward[lvl - 1]
    }
    lvl += 1
  }
  true
}
