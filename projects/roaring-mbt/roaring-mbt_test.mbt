// Spec-level tests (S4 spec-first, written before implementation).
// Spec source: arXiv:1603.06549 — exact membership, two-level structure,
// array/bitmap containers with 4096-value threshold conversion.

///|
test "exact membership on array container range" {
  let bm = @roaring.Roaring::new()
  for v in 0..<1000 {
    bm.add(v.reinterpret_as_uint())
  }
  for v in 0..<1000 {
    assert_eq(bm.contains(v.reinterpret_as_uint()), true)
  }
  for v in 1000..<2000 {
    assert_eq(bm.contains(v.reinterpret_as_uint()), false)
  }
}

///|
test "containers stay sorted regardless of insertion order" {
  let bm = @roaring.Roaring::new()
  // high 16-bit keys inserted out of order
  bm.add(0x00020001U)
  bm.add(0x000000FFU)
  bm.add(0x0001ABCDU)
  assert_eq(bm.contains(0x000000FFU), true)
  assert_eq(bm.contains(0x0001ABCDU), true)
  assert_eq(bm.contains(0x00020001U), true)
  assert_eq(bm.contains(0x00010000U), false)
}

///|
test "add is idempotent (no duplicate cardinality)" {
  let bm = @roaring.Roaring::new()
  for _ in 0..<10 {
    bm.add(42U)
  }
  assert_eq(bm.contains(42U), true)
  // removing once must fully remove despite repeated adds
  bm.remove(42U)
  assert_eq(bm.contains(42U), false)
}

///|
test "array container converts to bitmap past 4096 values" {
  let bm = @roaring.Roaring::new()
  // 4097 values sharing the same high key (value = v, v in 0..4097)
  for v in 0..<4097 {
    bm.add(v.reinterpret_as_uint())
  }
  for v in 0..<4097 {
    assert_eq(bm.contains(v.reinterpret_as_uint()), true)
  }
  assert_eq(bm.contains(4097U), false)
}

///|
test "bitmap container converts back to array below threshold on remove" {
  let bm = @roaring.Roaring::new()
  for v in 0..<4097 {
    bm.add(v.reinterpret_as_uint())
  }
  // drop from 4097 to exactly 4096 values -> should be array container again
  bm.remove(0U)
  for v in 1..<4097 {
    assert_eq(bm.contains(v.reinterpret_as_uint()), true)
  }
  assert_eq(bm.contains(0U), false)
}

///|
test "removing every value of a key removes the container" {
  let bm = @roaring.Roaring::new()
  bm.add(0x00050001U)
  bm.add(0x00050002U)
  bm.remove(0x00050001U)
  bm.remove(0x00050002U)
  assert_eq(bm.contains(0x00050001U), false)
  assert_eq(bm.contains(0x00050002U), false)
  // the key must be gone: re-adding works and membership still exact
  bm.add(0x00050001U)
  assert_eq(bm.contains(0x00050001U), true)
}

///|
test "large sparse keyspace roundtrip" {
  let bm = @roaring.Roaring::new()
  let probes : Array[UInt32] = [
    0U, 1U, 65535U, 65536U, 0x7FFFFFFFU, 0x80000000U, 0xFFFFFFFFU,
  ]
  for v in probes {
    bm.add(v)
  }
  for v in probes {
    assert_eq(bm.contains(v), true)
  }
  assert_eq(bm.contains(0x80000001U), false)
  for v in probes {
    bm.remove(v)
  }
  for v in probes {
    assert_eq(bm.contains(v), false)
  }
}
