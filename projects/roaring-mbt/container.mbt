///|
/// Threshold from arXiv:1603.06549: containers with at most 4096 values use
/// sorted arrays; denser ones use 1024x64-bit bitmaps.
let threshold : Int = 4096

///|
/// Sorted packed array container. vals is strictly increasing, values in 0..65535.
priv struct ArrayContainer {
  vals : Array[Int]
}

///|
/// Bitmap container: 1024 UInt64 words covering the full 16-bit range.
priv struct BitmapContainer {
  words : FixedArray[UInt64]
  mut cardinality : Int
}

///|
priv enum Container {
  Arr(ArrayContainer)
  Bmp(BitmapContainer)
}

///|
/// Binary search over a sorted array. Returns the index if found, otherwise
/// -(insertion_point + 1).
fn binary_search(arr : Array[Int], target : Int) -> Int {
  let mut lo = 0
  let mut hi = arr.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    let x = arr[mid]
    if x == target {
      return mid
    }
    if x < target {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  -(lo + 1)
}

///|
/// Insert v at pos, shifting the tail right.
fn[T] insert_at(arr : Array[T], pos : Int, v : T) -> Unit {
  arr.push(v)
  let mut i = arr.length() - 1
  while i > pos {
    arr[i] = arr[i - 1]
    i -= 1
  }
  arr[pos] = v
}

///|
/// Remove the element at pos, shifting the tail left.
fn[T] remove_at(arr : Array[T], pos : Int) -> Unit {
  let n = arr.length()
  let mut i = pos
  while i < n - 1 {
    arr[i] = arr[i + 1]
    i += 1
  }
  let _ = arr.pop()
}

///|
fn ArrayContainer::new() -> ArrayContainer {
  { vals: [] }
}

///|
fn ArrayContainer::contains(self : ArrayContainer, v : Int) -> Bool {
  binary_search(self.vals, v) >= 0
}

///|
/// Add v; returns true if it was not present before.
fn ArrayContainer::add(self : ArrayContainer, v : Int) -> Bool {
  let i = binary_search(self.vals, v)
  if i >= 0 {
    false
  } else {
    insert_at(self.vals, -(i + 1), v)
    true
  }
}

///|
/// Remove v; returns true if it was present.
fn ArrayContainer::remove(self : ArrayContainer, v : Int) -> Bool {
  let i = binary_search(self.vals, v)
  if i >= 0 {
    remove_at(self.vals, i)
    true
  } else {
    false
  }
}

///|
fn BitmapContainer::new() -> BitmapContainer {
  { words: FixedArray::make(1024, 0UL), cardinality: 0 }
}

///|
fn BitmapContainer::contains(self : BitmapContainer, v : Int) -> Bool {
  (self.words[v >> 6] & (1UL << (v & 63))) != 0UL
}

///|
/// Add v; returns true if it was not present before.
fn BitmapContainer::add(self : BitmapContainer, v : Int) -> Bool {
  let w = v >> 6
  let bit = 1UL << (v & 63)
  if (self.words[w] & bit) != 0UL {
    false
  } else {
    self.words[w] = self.words[w] | bit
    self.cardinality += 1
    true
  }
}

///|
/// Remove v; returns true if it was present.
fn BitmapContainer::remove(self : BitmapContainer, v : Int) -> Bool {
  let w = v >> 6
  let bit = 1UL << (v & 63)
  if (self.words[w] & bit) != 0UL {
    self.words[w] = self.words[w] & (bit ^ 0xFFFFFFFFFFFFFFFFUL)
    self.cardinality -= 1
    true
  } else {
    false
  }
}

///|
/// Expand a sorted array container into a bitmap container.
fn ArrayContainer::to_bitmap(self : ArrayContainer) -> BitmapContainer {
  let b = BitmapContainer::new()
  for v in self.vals {
    let _ = b.add(v)
  }
  b
}

///|
/// Compress a bitmap container into a sorted array container.
fn BitmapContainer::to_array(self : BitmapContainer) -> ArrayContainer {
  let a = ArrayContainer::new()
  for wi in 0..<1024 {
    let w = self.words[wi]
    for bit in 0..<64 {
      if ((w >> bit) & 1UL) == 1UL {
        a.vals.push((wi << 6) + bit)
      }
    }
  }
  a
}
