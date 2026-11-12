///|
/// A simple fixed-size bit vector backed by 64-bit words.
priv struct BitVec {
  words : Array[UInt64]
}

///|
fn BitVec::new_zero(nbits : Int32) -> BitVec {
  BitVec::{ words: Array::make((nbits + 63) / 64, 0UL), }
}

///|
fn mask64(l : Int32) -> UInt64 {
  if l >= 64 {
    0xFFFFFFFFFFFFFFFFUL
  } else if l <= 0 {
    0UL
  } else {
    (1UL << l) - 1UL
  }
}

///|
fn popcount64(x0 : UInt64) -> Int32 {
  let mut x = x0
  let mut c : Int32 = 0
  while x != 0UL {
    x = x & (x - 1UL)
    c += 1
  }
  c
}

///|
fn BitVec::set_bit(self : BitVec, i : Int32) -> Unit {
  self.words[i / 64] = self.words[i / 64] | (1UL << (i % 64))
}

///|
/// Write the low `l` bits of `v` starting at bit offset `i` (may span words).
fn BitVec::write_field(self : BitVec, i : Int32, l : Int32, v : UInt64) -> Unit {
  if l <= 0 {
    return
  }
  let mut pos = i
  let mut rest = l
  let mut val = v
  while rest > 0 {
    let off = pos % 64
    let take = if rest < 64 - off { rest } else { 64 - off }
    let m = mask64(take)
    let mw = m << off
    // clear the target region: a & ~b == a ^ (a & b)
    let cleared = self.words[pos / 64] ^ (self.words[pos / 64] & mw)
    self.words[pos / 64] = cleared | ((val & m) << off)
    val = val >> take
    pos += take
    rest -= take
  }
}

///|
/// Read `l` bits starting at bit offset `i` (may span words).
fn BitVec::read_field(self : BitVec, i : Int32, l : Int32) -> UInt64 {
  if l <= 0 {
    return 0UL
  }
  let mut pos = i
  let mut rest = l
  let mut acc : UInt64 = 0UL
  let mut shift : Int32 = 0
  while rest > 0 {
    let off = pos % 64
    let take = if rest < 64 - off { rest } else { 64 - off }
    let m = mask64(take)
    acc = acc | (((self.words[pos / 64] >> off) & m) << shift)
    pos += take
    shift += take
    rest -= take
  }
  acc
}

///|
/// Position (0-based) of the k-th set bit, or -1 if absent. Linear scan.
fn BitVec::select1(self : BitVec, k : Int32) -> Int32 {
  let mut seen : Int32 = 0
  for wi, w in self.words {
    let c = popcount64(w)
    if seen + c > k {
      // the k-th one (0-based) lies in word wi
      let mut w = w
      let mut rem = k - seen
      let mut pos = wi * 64
      while rem > 0 {
        w = w & (w - 1UL) // clear lowest set bit
        rem -= 1
      }
      while (w & 1UL) == 0UL {
        w = w >> 1
        pos += 1
      }
      return pos
    }
    seen += c
  }
  -1
}
