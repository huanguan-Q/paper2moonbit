// String-level API: map distinct characters to ranks 1..K (sorted by code
// point), append the sentinel 0, run the core, drop the sentinel suffix.

///|
pub fn suffix_array(text : String) -> Array[Int32] {
  let present : Array[Int32] = []
  for ch in text {
    let c = ch.to_int()
    let mut found = false
    for k in 0..<present.length() {
      if present[k] == c {
        found = true
        break
      }
    }
    if !found {
      present.push(c)
    }
  }
  present.sort()
  let rank_of : Array[Int32] = Array::make(256, 0)
  for idx in 0..<present.length() {
    if present[idx] < 256 {
      rank_of[present[idx]] = idx + 1
    }
  }
  let encoded : Array[Int32] = []
  for ch in text {
    encoded.push(rank_of[ch.to_int()])
  }
  encoded.push(0)
  let sa = sais_core(encoded, present.length() + 1)
  let out : Array[Int32] = []
  for i in 1..<sa.length() {
    out.push(sa[i])
  }
  out
}
