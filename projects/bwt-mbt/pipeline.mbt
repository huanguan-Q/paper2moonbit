// End-to-end pipeline: BWT (Alg. C) -> MTF (Alg. M) -> zero-run (§5 variant).
// Structured in-memory output (no byte-level serialization; see BLUEPRINT
// deviation notes). The Huffman/arithmetic back-end of step M2 is replaced
// by zero-run coding per the paper's own §5 suggestion.

///|
/// Compressed block: the BWT index I and the zero-run-coded MTF stream.
/// L itself is recoverable from ZR + the MTF list, but we carry L's length
/// implicitly through the decoded stream.
pub struct BwtPacket {
  i : Int32
  zr : Array[Int32]
}

///|
/// Compress: S -> (I, ZR).
pub fn bwt_compress(s : Array[Int32]) -> BwtPacket {
  let (l, i) = bwt_forward(s)
  let r = mtf_encode(l)
  let zr = zero_run_encode(r)
  { i, zr, }
}

///|
/// Decompress: (I, ZR) -> S.
pub fn bwt_decompress(pkt : BwtPacket) -> Array[Int32] {
  let r = zero_run_decode(pkt.zr)
  let l = mtf_decode(r)
  bwt_inverse(l, pkt.i)
}
