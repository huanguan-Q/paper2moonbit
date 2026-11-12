// Byte/hex helpers for the RFC 8439 test vectors.

///|
/// Decode a hex string; ":" separators are tolerated (RFC notation).
pub fn hex_bytes(s : String) -> Array[Int32] {
  let buf = StringBuilder()
  for ch in s {
    if ch != ':' && ch != ' ' {
      buf.write_char(ch)
    }
  }
  let clean = buf.to_string()
  let out : Array[Int32] = []
  let codes = clean.to_array()
  let mut i = 0
  while i + 1 < codes.length() {
    let hi = hex_val(codes[i].to_int())
    let lo = hex_val(codes[i + 1].to_int())
    out.push(hi * 16 + lo)
    i += 2
  }
  out
}

///|
fn hex_val(c : Int32) -> Int32 {
  if c >= 48 && c <= 57 {
    c - 48
  } else if c >= 97 && c <= 102 {
    c - 87
  } else if c >= 65 && c <= 70 {
    c - 55
  } else {
    0
  }
}

///|
pub fn bytes_to_hex(bs : Array[Int32]) -> String {
  let digits = "0123456789abcdef"
  let buf = StringBuilder()
  for b in bs {
    buf.write_char(digits.to_array()[b / 16])
    buf.write_char(digits.to_array()[b % 16])
  }
  buf.to_string()
}

///|
/// Little-endian 4-byte word from bytes (RFC: state words are LE).
pub fn le_word(bs : Array[Int32], off : Int32) -> UInt32 {
  let w = bs[off].to_uint64() |
    (bs[off + 1].to_uint64() << 8) |
    (bs[off + 2].to_uint64() << 16) |
    (bs[off + 3].to_uint64() << 24)
  w.to_uint()
}

///|
/// Serialize a word as 4 little-endian bytes.
pub fn word_le(w : UInt32, out : Array[Int32]) -> Unit {
  let v = w.to_uint64()
  out.push((v & 0xffUL).to_int())
  out.push(((v >> 8) & 0xffUL).to_int())
  out.push(((v >> 16) & 0xffUL).to_int())
  out.push(((v >> 24) & 0xffUL).to_int())
}
