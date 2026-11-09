// Blackbox tests: spec-level behavior against @xor16filter public API.
// Spec source: arXiv:1912.08258 — membership always true for built keys;
// false positive rate epsilon ~= 0.3905 / 2^16 ~= 5.96e-6 for xor16.

///|
fn build_ok(keys : Array[UInt64]) -> @xor16filter.Xor16 {
  match @xor16filter.build(keys) {
    Ok(f) => f
    Err(msg) => abort("build unexpectedly failed: \{msg}")
  }
}

///|
test "build then all members hit" {
  let rng = Ref(42UL)
  let keys = Array(capacity=1000)
  for _ in 0..<1000 {
    keys.push(@xor16filter.splitmix64_next(rng))
  }
  let f = build_ok(keys)
  for key in keys {
    assert_eq(f.contains(key), true)
  }
}

///|
test "single key edge case" {
  let f = build_ok([0xDEADBEEFUL])
  assert_eq(f.contains(0xDEADBEEFUL), true)
}

///|
test "empty input builds" {
  match @xor16filter.build([]) {
    Ok(_) => ()
    Err(msg) => abort("empty build failed: \{msg}")
  }
}

///|
test "duplicate keys fail with diagnostic" {
  match @xor16filter.build([7UL, 7UL, 7UL]) {
    Ok(_) => abort("duplicate keys should not build")
    Err(_) => ()
  }
}

///|
test "false positive rate matches 0.3905 / 2^16" {
  let rng = Ref(12345UL)
  let keys = Array(capacity=10000)
  for _ in 0..<10000 {
    keys.push(@xor16filter.splitmix64_next(rng))
  }
  let f = build_ok(keys)
  // 5M distinct non-member probes; expected FPs ~= 5e6 * 5.96e-6 ~= 29.8.
  let probes = 5_000_000
  let mut hits = 0
  for _ in 0..<probes {
    let p = @xor16filter.splitmix64_next(rng)
    if f.contains(p) {
      hits += 1
    }
  }
  // Poisson(29.8): sigma ~= 5.5; bounds cover >30 sigma up and ~5 sigma down.
  assert_eq(hits < 200, true)
  assert_eq(hits > 3, true)
}
