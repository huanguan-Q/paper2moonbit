// Move-to-front coding: Alg. M (encode) / Alg. W (decode).
// Full alphabet: codes 0..255, initial list Y = 0,1,...,255.
// A small-alphabet entry point replicates the paper's worked example.

///|
/// Move-to-front list as a plain array; move-to-front implemented by
/// splicing (lists are tiny: 256 max).
fn mtf_step(list : Array[Int32], code : Int32) -> Int32 {
  let mut pos = 0
  while list[pos] != code {
    pos += 1
  }
  // splice the found character to the front
  let mut k = pos
  while k > 0 {
    list[k] = list[k - 1]
    k -= 1
  }
  list[0] = code
  pos
}

///|
/// Alg. M M1 with the full 256-code alphabet (initial Y = 0..255).
pub fn mtf_encode(s : Array[Int32]) -> Array[Int32] {
  let list : Array[Int32] = []
  for v in 0..<256 {
    list.push(v)
  }
  let r : Array[Int32] = []
  for c in s {
    r.push(mtf_step(list, c))
  }
  r
}

///|
/// Alg. W W2 with the full 256-code alphabet.
pub fn mtf_decode(r : Array[Int32]) -> Array[Int32] {
  let list : Array[Int32] = []
  for v in 0..<256 {
    list.push(v)
  }
  let s : Array[Int32] = []
  for x in r {
    s.push(list[x])
    let _ = mtf_step(list, list[x])
  }
  s
}

///|
/// Alg. M M1 restricted to an explicit initial list Y — used to reproduce
/// the paper's worked example (Y = [a, b, c, r]).
pub fn mtf_encode_small(
  s : Array[Int32],
  initial : Array[Int32],
) -> Array[Int32] {
  let list = initial.copy()
  let r : Array[Int32] = []
  for c in s {
    r.push(mtf_step(list, c))
  }
  r
}

///|
/// Alg. W W2 restricted to an explicit initial list Y.
pub fn mtf_decode_small(
  r : Array[Int32],
  initial : Array[Int32],
) -> Array[Int32] {
  let list = initial.copy()
  let s : Array[Int32] = []
  for x in r {
    s.push(list[x])
    let _ = mtf_step(list, list[x])
  }
  s
}
