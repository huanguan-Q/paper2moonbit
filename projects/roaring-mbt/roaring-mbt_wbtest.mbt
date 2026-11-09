// Whitebox tests: internal invariants (container transitions, binary search).

///|
test "binary_search found and miss positions" {
  let arr = [10, 20, 30, 40]
  assert_eq(binary_search(arr, 20), 1)
  assert_eq(binary_search(arr, 10), 0)
  assert_eq(binary_search(arr, 40), 3)
  assert_eq(binary_search(arr, 5), -1)
  assert_eq(binary_search(arr, 25), -3)
  assert_eq(binary_search(arr, 50), -5)
}

///|
test "array promotes to bitmap at 4097 distinct values" {
  let bm = Roaring::new()
  for v in 0..<4097 {
    bm.add(v.reinterpret_as_uint())
  }
  match bm.containers[0] {
    Bmp(b) => assert_eq(b.cardinality, 4097)
    Arr(_) => abort("expected bitmap container after 4097 adds")
  }
}

///|
test "bitmap demotes to array at 4096 cardinality on remove" {
  let bm = Roaring::new()
  for v in 0..<4097 {
    bm.add(v.reinterpret_as_uint())
  }
  bm.remove(0U)
  match bm.containers[0] {
    Arr(a) => assert_eq(a.vals.length(), 4096)
    Bmp(_) => abort("expected array container after demotion")
  }
}

///|
test "container table keys remain strictly increasing" {
  let bm = Roaring::new()
  for hi in [7, 2, 9, 2, 7, 1] {
    bm.add(((hi << 16) | 1).reinterpret_as_uint())
  }
  for i in 1..<bm.keys.length() {
    assert_eq(bm.keys[i - 1] < bm.keys[i], true)
  }
  assert_eq(bm.keys.length(), 4)
}

///|
test "bitmap to_array roundtrip preserves membership" {
  let a = ArrayContainer::new()
  let vals = [1, 2, 3, 63, 64, 65, 4095, 65535]
  for v in vals {
    let _ = a.add(v)
  }
  let b = a.to_bitmap()
  assert_eq(b.cardinality, vals.length())
  let a2 = b.to_array()
  assert_eq(a2.vals, vals)
}
