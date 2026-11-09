// SA-IS: linear-time suffix array construction by induced sorting.
//
// Provenance: algorithm from Nong, Zhang & Chan, "Linear Suffix Array
// Construction by Almost Pure Induced-Sorting", DCC 2009 (Fig. 1 framework).
// This file is an independent MoonBit coding of that published framework;
// no third-party source code was copied.
//
// CONTRACT: values ends with an explicit sentinel 0 (strictly smaller than
// every other symbol); the returned SA covers every suffix, sentinel first.

///|
pub struct LCG {
  priv mut state : UInt64
}

///|
pub fn LCG::new(seed : UInt64) -> LCG {
  { state: seed * 6364136223846793005UL + 1442695040888963407UL, }
}

///|
pub fn LCG::next_u64(self : LCG) -> UInt64 {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  self.state
}

///|
/// S-type marker: this suffix is strictly smaller than its right neighbor's
/// suffix (equal characters inherit the neighbor's type).
fn classify_types(values : Array[Int32]) -> FixedArray[Bool] {
  let n = values.length()
  let t : FixedArray[Bool] = FixedArray::make(n, false)
  t[n - 1] = true // the sentinel suffix is S-type
  if n >= 2 {
    t[n - 2] = false // it precedes a value > 0, so L-type
  }
  let mut i = n - 3
  while i >= 0 {
    if values[i] < values[i + 1] {
      t[i] = true
    } else if values[i] > values[i + 1] {
      t[i] = false
    } else {
      t[i] = t[i + 1]
    }
    i -= 1
  }
  t
}

///|
/// LMS position: an S-type whose left neighbor is L-type.
fn lms_positions(values : Array[Int32], t : FixedArray[Bool]) -> Array[Int32] {
  let out : Array[Int32] = []
  for k in 1..<values.length() {
    if t[k] && !t[k - 1] {
      out.push(k)
    }
  }
  out
}

///|
/// Bucket interior: starts (head, exclusive of prior buckets), ends (tail).
fn bucket_bounds(
  values : Array[Int32],
  alphabet_size : Int32,
) -> (Array[Int32], Array[Int32]) {
  let counts = Array::make(alphabet_size, 0)
  for v in values {
    counts[v] += 1
  }
  let starts = Array::make(alphabet_size, 0)
  let ends = Array::make(alphabet_size, 0)
  let mut acc = 0
  for sym in 0..<alphabet_size {
    starts[sym] = acc
    acc += counts[sym]
    ends[sym] = acc
  }
  (starts, ends)
}

///|
/// One induced-sorting pass over `values` with LMS-order seeds:
/// seed at tails (private cursor), sweep L-types head-ward, then S-types
/// tail-ward with a fresh tail cursor. Each pass rebuilds its cursors.
fn induce_pass(
  values : Array[Int32],
  t : FixedArray[Bool],
  seeds : Array[Int32],
  alphabet_size : Int32,
) -> Array[Int32] {
  let n = values.length()
  let (starts, ends) = bucket_bounds(values, alphabet_size)
  let sa : Array[Int32] = Array::make(n, -1)
  // seeds at bucket tails (provisional placement; the S-sweep re-decides
  // every tail slot from scratch, which is what makes stage-1 correct)
  let seed_head = Array::make(alphabet_size, 0)
  for sym in 0..<alphabet_size {
    seed_head[sym] = ends[sym]
  }
  let mut sk = seeds.length() - 1
  while sk >= 0 {
    let p = seeds[sk]
    seed_head[values[p]] -= 1
    sa[seed_head[values[p]]] = p
    sk -= 1
  }
  // L-type predecessors: sweep left to right over current SA contents
  let head = Array::make(alphabet_size, 0)
  for sym in 0..<alphabet_size {
    head[sym] = starts[sym]
  }
  for slot in 0..<n {
    let p = sa[slot]
    if p > 0 && !t[p - 1] {
      sa[head[values[p - 1]]] = p - 1
      head[values[p - 1]] += 1
    }
  }
  // S-type predecessors: sweep right to left over final L-state contents
  let tail = Array::make(alphabet_size, 0)
  for sym in 0..<alphabet_size {
    tail[sym] = ends[sym]
  }
  let mut slot = n - 1
  while slot >= 0 {
    let p = sa[slot]
    if p > 0 && t[p - 1] {
      tail[values[p - 1]] -= 1
      sa[tail[values[p - 1]]] = p - 1
    }
    slot -= 1
  }
  sa
}

///|
/// Are the LMS substrings starting at two LMS positions identical? An LMS
/// substring ends at (and includes) the next LMS position; equality compares
/// both the characters and the S/L types along the way.
fn lms_substrings_equal(
  values : Array[Int32],
  t : FixedArray[Bool],
  a : Int32,
  b : Int32,
) -> Bool {
  let mut off = 0
  while true {
    let pa = a + off
    let pb = b + off
    if values[pa] != values[pb] || t[pa] != t[pb] {
      return false
    }
    if off > 0 {
      let a_end = t[pa] && !t[pa - 1]
      let b_end = t[pb] && !t[pb - 1]
      if a_end || b_end {
        return a_end && b_end
      }
    }
    off += 1
  }
  false
}

///|
/// SA-IS core (Fig. 1 framework). CONTRACT: values ends with one explicit
/// sentinel 0; returns the SA with the sentinel suffix at position 0.
pub fn sais_core(values : Array[Int32], alphabet_size : Int32) -> Array[Int32] {
  let n = values.length()
  if n == 0 {
    return []
  }
  if n == 1 {
    return [0]
  }
  let t = classify_types(values)
  let lms = lms_positions(values, t)
  let n1 = lms.length()
  // stage 1: induced sort seeded with (unordered) LMS suffixes
  let first = induce_pass(values, t, lms, alphabet_size)
  // name LMS substrings in their first-pass order
  let names = Array::make(n, -1)
  let mut name = -1
  let mut prev = -1
  for slot in 0..<n {
    let p = first[slot]
    if p > 0 && t[p] && !t[p - 1] {
      if prev < 0 || !lms_substrings_equal(values, t, prev, p) {
        name += 1
      }
      names[p] = name
      prev = p
    }
  }
  // reduced string over LMS positions in text order; its last symbol is the
  // sentinel's name 0, satisfying this same contract recursively
  let reduced : Array[Int32] = []
  for p in lms {
    reduced.push(names[p])
  }
  let lms_order : Array[Int32] = Array::make(n1, 0)
  if name + 1 == n1 {
    // distinct names are already ranks: invert the text-order mapping
    for k in 0..<n1 {
      lms_order[reduced[k]] = lms[k]
    }
  } else {
    let reduced_sa = sais_core(reduced, name + 1)
    for k in 0..<reduced_sa.length() {
      lms_order[k] = lms[reduced_sa[k]]
    }
  }
  // stage 2: final induced sort from the ordered LMS suffixes
  induce_pass(values, t, lms_order, alphabet_size)
}
