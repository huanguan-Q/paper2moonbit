///|
/// Xor16 filter (arXiv:1912.08258). Fingerprints are 16-bit values stored
/// (unpacked) as UInt64 slots. Faithful to FastFilter/xor_singleheader
/// xorfilter.h semantics; see BLUEPRINT.md for documented deviations.
pub(all) struct Xor16 {
  seed : UInt64
  block_length : Int
  fingerprints : FixedArray[UInt64]
}

///|
/// 16-bit fingerprint of the scrambled hash.
fn fingerprint16(hash : UInt64) -> UInt64 {
  (hash ^ (hash >> 32)) & 0xFFFFUL
}

///|
/// Within-block position from the low 32 bits of hash.
fn h0w(hash : UInt64, b : Int) -> Int {
  reduce(low32(hash), b)
}

///|
/// Within-block position from rotl64(hash, 21) truncated to 32 bits.
fn h1w(hash : UInt64, b : Int) -> Int {
  reduce(low32(rotl64(hash, 21)), b)
}

///|
/// Within-block position from rotl64(hash, 42) truncated to 32 bits.
fn h2w(hash : UInt64, b : Int) -> Int {
  reduce(low32(rotl64(hash, 42)), b)
}

///|
/// Slot position of hash within block `block` (0, 1, or 2).
fn pos_in_block(hash : UInt64, b : Int, block : Int) -> Int {
  match block {
    0 => h0w(hash, b)
    1 => h1w(hash, b)
    _ => h2w(hash, b)
  }
}

///|
/// Amortized-constant random access, since capacity is fixed up front.
/// Reference: capacity = 32 + 1.23*size, rounded up to a multiple of 3.
fn block_len_for(n : Int) -> Int {
  let mut capacity = 32 + (1.23 * n.to_double()).to_int()
  if capacity < 3 {
    capacity = 3
  }
  if capacity % 3 != 0 {
    capacity = capacity + (3 - capacity % 3)
  }
  capacity / 3
}

///|
priv struct KeyIndex {
  index : Int
  hash : UInt64
}

///|
/// Build an xor16 filter from distinct 64-bit keys. Retries with fresh
/// splitmix64 seeds up to 100 times; fails if the hypergraph is not peelable
/// (typically caused by duplicate keys).
pub fn build(keys : Array[UInt64]) -> Result[Xor16, String] {
  let n = keys.length()
  let b = block_len_for(n)
  let rng = Ref(0x726B2B9D438B9D00UL)
  let mut seed : UInt64 = 0UL
  for attempt in 0..<100 {
    match try_build(keys, n, b, seed) {
      Ok(filter) => return Ok(filter)
      Err(msg) => {
        if attempt == 99 {
          return Err(
            "xor16 build failed after 100 attempts (duplicate keys?): \{msg}",
          )
        }
      }
    }
    seed = splitmix64_next(rng)
  }
  abort("unreachable")
}

///|
fn try_build(
  keys : Array[UInt64],
  n : Int,
  b : Int,
  seed : UInt64,
) -> Result[Xor16, String] {
  // Per-slot accumulators for the three blocks: XOR of full hashes + count.
  let ms : Array[FixedArray[UInt64]] = [
    FixedArray::make(b, 0UL),
    FixedArray::make(b, 0UL),
    FixedArray::make(b, 0UL),
  ]
  let cs : Array[FixedArray[Int]] = [
    FixedArray::make(b, 0),
    FixedArray::make(b, 0),
    FixedArray::make(b, 0),
  ]
  for key in keys {
    let hash = murmur64(key + seed)
    for k in 0..<3 {
      let p = pos_in_block(hash, b, k)
      ms[k][p] = ms[k][p] ^ hash
      cs[k][p] = cs[k][p] + 1
    }
  }
  // Peeling worklist over all slots; LIFO order is fine.
  // Each slot is enqueued at most once here plus at most once when its
  // count later drops to 1, so capacity 3*b suffices.
  let queue : FixedArray[KeyIndex] = FixedArray::make(3 * b, { index: 0, hash: 0UL })
  let mut qt = 0
  for k in 0..<3 {
    for i in 0..<b {
      if cs[k][i] == 1 {
        queue[qt] = { index: i + k * b, hash: ms[k][i] }
        qt += 1
      }
    }
  }
  // Stack of resolved (slot, hash); backward assignment consumes it in reverse.
  let stack : FixedArray[KeyIndex] = FixedArray::make(n, { index: 0, hash: 0UL })
  let mut ss = 0
  while qt > 0 {
    qt -= 1
    let ki = queue[qt]
    let block = ki.index / b
    let slot = ki.index - block * b
    if cs[block][slot] == 0 {
      continue
    }
    stack[ss] = ki
    ss += 1
    let hash = ki.hash
    for other in [(block + 1) % 3, (block + 2) % 3] {
      let p = pos_in_block(hash, b, other)
      ms[other][p] = ms[other][p] ^ hash
      cs[other][p] = cs[other][p] - 1
      if cs[other][p] == 1 {
        queue[qt] = { index: p + other * b, hash: ms[other][p] }
        qt += 1
      }
    }
  }
  if ss != n {
    return Err("hypergraph not peelable with this seed")
  }
  // Backward assignment: pop the stack (LIFO) and satisfy each key's equation:
  // fingerprint(hash) == fps[p0] ^ fps[p1] ^ fps[p2] at its three slots.
  let fps : FixedArray[UInt64] = FixedArray::make(3 * b, 0UL)
  while ss > 0 {
    ss -= 1
    let ki = stack[ss]
    let hash = ki.hash
    let block = ki.index / b
    let o1 = (block + 1) % 3
    let o2 = (block + 2) % 3
    let p1 = pos_in_block(hash, b, o1) + o1 * b
    let p2 = pos_in_block(hash, b, o2) + o2 * b
    let val = fingerprint16(hash) ^ (fps[p1] ^ fps[p2])
    fps[ki.index] = val & 0xFFFFUL
  }
  Ok({ seed, block_length: b, fingerprints: fps })
}

///|
/// Membership query: always true for keys used at build time; false-positive
/// rate ~0.3905 / 2^16 for other keys.
pub fn Xor16::contains(self : Xor16, key : UInt64) -> Bool {
  let hash = murmur64(key + self.seed)
  let f = fingerprint16(hash)
  let b = self.block_length
  let fp0 = self.fingerprints[h0w(hash, b)]
  let fp1 = self.fingerprints[h1w(hash, b) + b]
  let fp2 = self.fingerprints[h2w(hash, b) + 2 * b]
  f == ((fp0 ^ fp1) ^ fp2)
}
