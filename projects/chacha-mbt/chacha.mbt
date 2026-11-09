// ChaCha20 block function and stream cipher — RFC 8439 §2.1-2.4.

///|
const CW1 : UInt32 = 0x61707865U // "expa"

///|
const CW2 : UInt32 = 0x3320646eU // "nd 3"

///|
const CW3 : UInt32 = 0x79622d32U // "2-by"

///|
const CW4 : UInt32 = 0x6b206574U // "te k"

///|

///|
/// n-bit left roll on UInt (32-bit).
fn rol(x : UInt32, n : Int32) -> UInt32 {
  (x << n) | (x >> (32 - n))
}

///|
pub struct QrResult {
  a : UInt32
  b : UInt32
  c : UInt32
  d : UInt32
}

///|
/// §2.1 quarter round: 4 ARX lines, addition mod 2^32, xor, left roll.
pub fn quarter_round(
  a : UInt32,
  b : UInt32,
  c : UInt32,
  d : UInt32,
) -> QrResult {
  let mut a = a
  let mut b = b
  let mut c = c
  let mut d = d
  a = a.add(b)
  d = d ^ a
  d = rol(d, 16)
  c = c.add(d)
  b = b ^ c
  b = rol(b, 12)
  a = a.add(b)
  d = d ^ a
  d = rol(d, 8)
  c = c.add(d)
  b = b ^ c
  b = rol(b, 7)
  { a, b, c, d, }
}

///|
/// §2.2 QUARTERROUND(x,y,z,w) on a 16-word state; returns a new state.
pub fn quarter_round_state(
  st : FixedArray[UInt32],
  x : Int32,
  y : Int32,
  z : Int32,
  w : Int32,
) -> FixedArray[UInt32] {
  let out : FixedArray[UInt32] = FixedArray::make(16, 0U)
  for i in 0..<16 {
    out[i] = st[i]
  }
  let r = quarter_round(st[x], st[y], st[z], st[w])
  out[x] = r.a
  out[y] = r.b
  out[z] = r.c
  out[w] = r.d
  out
}

///|
/// Build the initial state (§2.3): constants + LE key words + counter + nonce.
fn initial_state(
  key : Array[Int32],
  counter : UInt32,
  nonce : Array[Int32],
) -> FixedArray[UInt32] {
  let st : FixedArray[UInt32] = FixedArray::make(16, 0U)
  st[0] = CW1
  st[1] = CW2
  st[2] = CW3
  st[3] = CW4
  for i in 0..<8 {
    st[4 + i] = le_word(key, i * 4)
  }
  st[12] = counter
  for i in 0..<3 {
    st[13 + i] = le_word(nonce, i * 4)
  }
  st
}

///|
/// §2.3 block function: 20 rounds (10 column + 10 diagonal quarter rounds),
/// then add the original state and serialize little-endian (64 bytes).
pub fn chacha20_block(
  key : Array[Int32],
  counter : UInt32,
  nonce : Array[Int32],
) -> Array[Int32] {
  let init = initial_state(key, counter, nonce)
  let st : FixedArray[UInt32] = FixedArray::make(16, 0U)
  for i in 0..<16 {
    st[i] = init[i]
  }
  // 10 column rounds interleaved with 10 diagonal rounds
  let mut round = 0
  while round < 10 {
    // column rounds
    let r1 = quarter_round(st[0], st[4], st[8], st[12])
    st[0] = r1.a
    st[4] = r1.b
    st[8] = r1.c
    st[12] = r1.d
    let r2 = quarter_round(st[1], st[5], st[9], st[13])
    st[1] = r2.a
    st[5] = r2.b
    st[9] = r2.c
    st[13] = r2.d
    let r3 = quarter_round(st[2], st[6], st[10], st[14])
    st[2] = r3.a
    st[6] = r3.b
    st[10] = r3.c
    st[14] = r3.d
    let r4 = quarter_round(st[3], st[7], st[11], st[15])
    st[3] = r4.a
    st[7] = r4.b
    st[11] = r4.c
    st[15] = r4.d
    // diagonal rounds
    let d1 = quarter_round(st[0], st[5], st[10], st[15])
    st[0] = d1.a
    st[5] = d1.b
    st[10] = d1.c
    st[15] = d1.d
    let d2 = quarter_round(st[1], st[6], st[11], st[12])
    st[1] = d2.a
    st[6] = d2.b
    st[11] = d2.c
    st[12] = d2.d
    let d3 = quarter_round(st[2], st[7], st[8], st[13])
    st[2] = d3.a
    st[7] = d3.b
    st[8] = d3.c
    st[13] = d3.d
    let d4 = quarter_round(st[3], st[4], st[9], st[14])
    st[3] = d4.a
    st[4] = d4.b
    st[9] = d4.c
    st[14] = d4.d
    round += 1
  }
  // add original state
  let out : Array[Int32] = []
  for i in 0..<16 {
    word_le(st[i].add(init[i]), out)
  }
  out
}

///|
/// §2.4 stream cipher: keystream blocks with increasing counter, XOR pt.
pub fn chacha20_encrypt(
  key : Array[Int32],
  counter : UInt32,
  nonce : Array[Int32],
  plaintext : Array[Int32],
) -> Array[Int32] {
  let out : Array[Int32] = []
  let n = plaintext.length()
  let mut j = 0
  while j * 64 < n {
    let ks = chacha20_block(key, counter.add(j.to_uint()), nonce)
    let start = j * 64
    let end = if start + 64 < n { start + 64 } else { n }
    let mut k = start
    while k < end {
      out.push(plaintext[k] ^ ks[k - start])
      k += 1
    }
    j += 1
  }
  out
}
