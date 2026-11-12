///|
/// Deterministic LCG — same seed must always produce the same stream.
pub struct LCG {
  state : Ref[UInt64]
}

///|
pub fn LCG::new(seed : UInt64) -> LCG {
  { state: Ref(seed), }
}

///|
pub fn LCG::next_u64(self : LCG) -> UInt64 {
  let s = self.state.val * 6364136223846793005UL + 1442695040888963407UL
  self.state.val = s
  s
}
