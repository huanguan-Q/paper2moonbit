// Poly1305 MAC (RFC 8439 §2.5) on core BigInt (mod 2^130-5), and the
// AEAD_CHACHA20_POLY1305 combination (§2.8). DEVIATION: the RFC advises
// constant-time limb implementations (poly1305-donna); this port uses the
// core BigInt library for clarity — a constant-time port is future work.

///|

///|
/// Decode a little-endian byte slice into a BigInt.
fn le_bytes_to_num(bs : Array[Int32], start : Int32, len : Int32) -> BigInt {
  let mut acc = BigInt::from_int(0)
  let mut i = len - 1
  while i >= 0 {
    acc = acc.mul(BigInt::from_int(256)).add(BigInt::from_int(bs[start + i]))
    i -= 1
  }
  acc
}

///|
/// Serialize the low 16 bytes of a BigInt little-endian.
fn num_to_16_le(n : BigInt) -> Array[Int32] {
  let out : Array[Int32] = Array::make(16, 0)
  let mut v = n
  let base = BigInt::from_int(256)
  for i in 0..<16 {
    let d = v.mod(base)
    out[i] = d.to_int()
    v = v.div(base)
  }
  out
}

///|
/// §2.5.1 clamp: r &= 0x0ffffffc0ffffffc0ffffffc0fffffff
pub fn clamp_r(r : BigInt) -> BigInt {
  // mask 0x0ffffffc0ffffffc0ffffffc0fffffff, built via shl (no hex parse)
  let part = BigInt::from_int(0x0ffffffc)
  let top = BigInt::from_int(0x0fffffff)
  let mask = part.shl(96).add(part.shl(64)).add(part.shl(32)).add(top)
  r & mask
}

///|
/// §2.5.1 poly1305_mac: Acc = ((Acc+block)*r) % P over 16-byte blocks with
/// a 0x01 byte appended to each (P = 2^130 - 5); tag = (Acc + s) low 16 LE.
pub fn poly1305_mac(key : Array[Int32], msg : Array[Int32]) -> Array[Int32] {
  let r = clamp_r(le_bytes_to_num(key, 0, 16))
  let s = le_bytes_to_num(key, 16, 16)
  let p = BigInt::from_int(1).shl(130).sub(BigInt::from_int(5))
  let mut acc = BigInt::from_int(0)
  let n = msg.length()
  let blocks = (n + 15) / 16
  let mut i = 0
  while i < blocks {
    let start = i * 16
    let len = if start + 16 <= n { 16 } else { n - start }
    // block bytes little-endian, plus the 0x01 byte beyond the octets
    let n = le_bytes_to_num(msg, start, len).add(
      BigInt::from_int(1).shl(len * 8),
    )
    acc = acc.add(n)
    acc = acc.mul(r).mod(p)
    i += 1
  }
  let result = acc.add(s)
  num_to_16_le(result)
}

///|
pub struct AeadResult {
  ciphertext : Array[Int32]
  tag : Array[Int32]
}

///|
/// §2.8 AEAD_CHACHA20_POLY1305: block 0 derives the one-time Poly key
/// (counter = 0), ciphertext uses counters starting at 1; MAC input is
/// AAD || pad16 || CT || pad16 || LE64(len(AAD)) || LE64(len(CT)).
pub fn aead_chacha20_poly1305(
  key : Array[Int32],
  nonce : Array[Int32],
  aad : Array[Int32],
  plaintext : Array[Int32],
) -> AeadResult {
  let block0 = chacha20_block(key, 0, nonce)
  let polykey = Array::make(32, 0)
  for i in 0..<32 {
    polykey[i] = block0[i]
  }
  let ciphertext = chacha20_encrypt(key, 1, nonce, plaintext)
  // MAC input construction
  let mac_data : Array[Int32] = []
  for b in aad {
    mac_data.push(b)
  }
  pad16(mac_data, aad.length())
  for b in ciphertext {
    mac_data.push(b)
  }
  pad16(mac_data, ciphertext.length())
  let alen = aad.length().to_uint64()
  mac_data.push((alen & 0xffUL).to_int())
  mac_data.push(((alen >> 8) & 0xffUL).to_int())
  mac_data.push(((alen >> 16) & 0xffUL).to_int())
  mac_data.push(((alen >> 24) & 0xffUL).to_int())
  mac_data.push(((alen >> 32) & 0xffUL).to_int())
  mac_data.push(((alen >> 40) & 0xffUL).to_int())
  mac_data.push(((alen >> 48) & 0xffUL).to_int())
  mac_data.push(((alen >> 56) & 0xffUL).to_int())
  let clen = ciphertext.length().to_uint64()
  mac_data.push((clen & 0xffUL).to_int())
  mac_data.push(((clen >> 8) & 0xffUL).to_int())
  mac_data.push(((clen >> 16) & 0xffUL).to_int())
  mac_data.push(((clen >> 24) & 0xffUL).to_int())
  mac_data.push(((clen >> 32) & 0xffUL).to_int())
  mac_data.push(((clen >> 40) & 0xffUL).to_int())
  mac_data.push(((clen >> 48) & 0xffUL).to_int())
  mac_data.push(((clen >> 56) & 0xffUL).to_int())
  let tag = poly1305_mac(polykey, mac_data)
  { ciphertext, tag, }
}

///|
/// Pad the working buffer with zero bytes up to the next 16-byte boundary
/// relative to the already-written content of length `written`.
fn pad16(buf : Array[Int32], written : Int32) -> Unit {
  let rem = written % 16
  if rem != 0 {
    let mut k = 16 - rem
    while k > 0 {
      buf.push(0)
      k -= 1
    }
  }
}
