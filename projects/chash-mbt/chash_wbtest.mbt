// Paper-criterion tests: consistent hashing (Karger et al., STOC'97 §4).
// All judgments from Thm 4.1 and §4.4 definitions, seeded & deterministic.

///|
test "assignment stays inside the view (T-MEMBER)" {
  let h = RangedHash::new(seed=7, points_per_bucket=8)
  let mut b = 0
  while b < 16 {
    h.add_bucket(b)
    b += 1
  }
  let rng = LCG::new(42)
  for _ in 0..<500 {
    let item = (rng.next_u64() % 10000UL).to_int()
    let owner = h.assign(item)
    assert_eq(h.has_bucket(owner), true)
  }
}

///|
test "monotonicity holds over random view pairs (T-MONO)" {
  // §4.1 Def: V1 ⊆ V2 and f^V2(i) ∈ V1 implies f^V1(i) = f^V2(i)
  for trial_seed in [1UL, 2UL, 3UL] {
    let h1 = RangedHash::new(seed=trial_seed, points_per_bucket=8)
    let h2 = RangedHash::new(seed=trial_seed, points_per_bucket=8)
    // h1 sees buckets {0..7}, h2 sees {0..15}: V1 ⊂ V2
    let mut b = 0
    while b < 16 {
      h2.add_bucket(b)
      if b < 8 {
        h1.add_bucket(b)
      }
      b += 1
    }
    let rng = LCG::new(trial_seed + 100UL)
    for _ in 0..<300 {
      let item = (rng.next_u64() % 10000UL).to_int()
      let f2 = h2.assign(item)
      let f1 = h1.assign(item)
      if h1.has_bucket(f2) {
        assert_eq(f1, f2)
      }
    }
  }
}

///|
test "adding a bucket only steals for itself (T-MONO new-bucket corollary)" {
  // "an item may move from an old bucket to a new bucket, but not from one
  // old bucket to another" — every changed assignment lands on the NEW bucket
  let h = RangedHash::new(seed=11, points_per_bucket=8)
  let mut b = 0
  while b < 12 {
    h.add_bucket(b)
    b += 1
  }
  let items : Array[Int32] = []
  let rng = LCG::new(5)
  for _ in 0..<2000 {
    items.push((rng.next_u64() % 100000UL).to_int())
  }
  let before : Array[Int32] = []
  for item in items {
    before.push(h.assign(item))
  }
  let new_bucket = 99
  h.add_bucket(new_bucket)
  let mut moved = 0
  let mut i = 0
  while i < items.length() {
    let after = h.assign(items[i])
    if before[i] != after {
      moved += 1
      assert_eq(after, new_bucket)
    }
    i += 1
  }
  // smoothness: moved fraction ≤ 4/(n+1) (Thm 4.1.2 balance consequence)
  let frac = moved.to_double() / items.length().to_double()
  assert_eq(frac <= 4.0 / 13.0, true)
}

///|
test "removing a bucket only displaces its own items (T-SMOOTH-REMOVE)" {
  let h = RangedHash::new(seed=13, points_per_bucket=8)
  let mut b = 0
  while b < 16 {
    h.add_bucket(b)
    b += 1
  }
  let items : Array[Int32] = []
  let rng = LCG::new(9)
  for _ in 0..<2000 {
    items.push((rng.next_u64() % 100000UL).to_int())
  }
  // record full mapping before removal
  let owner_before : Array[Int32] = []
  for item in items {
    owner_before.push(h.assign(item))
  }
  let doomed = 5
  let _ = h.remove_bucket(doomed)
  let mut i = 0
  while i < items.length() {
    let after = h.assign(items[i])
    if owner_before[i] != doomed {
      assert_eq(after, owner_before[i]) // untouched
    } else {
      assert_eq(after != doomed, true) // displaced to a survivor
      assert_eq(h.has_bucket(after), true)
    }
    i += 1
  }
}

///|
test "balance: bucket shares bounded by 4/|V| (T-BALANCE)" {
  // Thm 4.1.2: fraction per bucket is O(1/|V|); constant-factor window
  let h = RangedHash::new(seed=21, points_per_bucket=8)
  let n_buckets = 16
  let mut b = 0
  while b < n_buckets {
    h.add_bucket(b)
    b += 1
  }
  let counts = Array::make(n_buckets, 0)
  let rng = LCG::new(77)
  let n_items = 10000
  for _ in 0..<n_items {
    let item = (rng.next_u64() % 1000000UL).to_int()
    let owner = h.assign(item)
    counts[owner] += 1
  }
  let mut mx = 0
  for c in counts {
    if c > mx {
      mx = c
    }
  }
  let max_frac = mx.to_double() / n_items.to_double()
  assert_eq(max_frac <= 4.0 / n_buckets.to_double(), true)
}

///|
test "replication improves balance (T-REPL)" {
  // §4.2: "we actually need to have more than one point" per bucket
  let h1 = RangedHash::new(seed=31, points_per_bucket=1)
  let h8 = RangedHash::new(seed=31, points_per_bucket=8)
  let mut b = 0
  while b < 16 {
    h1.add_bucket(b)
    h8.add_bucket(b)
    b += 1
  }
  let rng1 = LCG::new(500)
  let counts1 = Array::make(16, 0)
  let counts8 = Array::make(16, 0)
  for _ in 0..<8000 {
    let item = (rng1.next_u64() % 1000000UL).to_int()
    counts1[h1.assign(item)] += 1
    counts8[h8.assign(item)] += 1
  }
  let mut mx1 = 0
  let mut mx8 = 0
  for c in counts1 {
    if c > mx1 {
      mx1 = c
    }
  }
  for c in counts8 {
    if c > mx8 {
      mx8 = c
    }
  }
  // replicated bucket spreads its points -> strictly better max share
  assert_eq(mx8 < mx1, true)
}
