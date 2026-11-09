///|
/// Roaring bitmap over the 32-bit domain (arXiv:1603.06549 core subset).
/// Exact membership: no false positives or false negatives.
pub struct Roaring {
  priv keys : Array[Int]
  priv containers : Array[Container]
}

///|
pub fn Roaring::new() -> Roaring {
  { keys: [], containers: [] }
}

///|
fn container_contains(c : Container, v : Int) -> Bool {
  match c {
    Arr(a) => a.contains(v)
    Bmp(b) => b.contains(v)
  }
}

///|
/// Split a 32-bit value into high key and low in-container value.
fn split(value : UInt32) -> (Int, Int) {
  ((value >> 16).reinterpret_as_int(), (value & 0xFFFFU).reinterpret_as_int())
}

///|
pub fn Roaring::contains(self : Roaring, value : UInt32) -> Bool {
  let (hi, lo) = split(value)
  let i = binary_search(self.keys, hi)
  if i >= 0 {
    container_contains(self.containers[i], lo)
  } else {
    false
  }
}

///|
pub fn Roaring::add(self : Roaring, value : UInt32) -> Unit {
  let (hi, lo) = split(value)
  let i = binary_search(self.keys, hi)
  if i >= 0 {
    match self.containers[i] {
      Arr(a) => {
        if a.add(lo) && a.vals.length() > threshold {
          // 4097th distinct value: promote to a bitmap container
          self.containers[i] = Bmp(a.to_bitmap())
        }
      }
      Bmp(b) => {
        let _ = b.add(lo)
      }
    }
  } else {
    // new key: fresh single-value array container at the sorted position
    let pos = -(i + 1)
    let a = ArrayContainer::new()
    let _ = a.add(lo)
    insert_at(self.keys, pos, hi)
    insert_at(self.containers, pos, Arr(a))
  }
}

///|
pub fn Roaring::remove(self : Roaring, value : UInt32) -> Unit {
  let (hi, lo) = split(value)
  let i = binary_search(self.keys, hi)
  if i >= 0 {
    match self.containers[i] {
      Arr(a) => {
        if a.remove(lo) && a.vals.is_empty() {
          remove_at(self.keys, i)
          remove_at(self.containers, i)
        }
      }
      Bmp(b) => {
        if b.remove(lo) {
          if b.cardinality == 0 {
            remove_at(self.keys, i)
            remove_at(self.containers, i)
          } else if b.cardinality <= threshold {
            // demote back to a packed array per the paper's threshold rule
            self.containers[i] = Arr(b.to_array())
          }
        }
      }
    }
  }
}
