// Seeded 64-bit LCG — deterministic replay (shared recipe).

///|
pub struct LCG {
  priv mut state : UInt64
}

///|
pub fn LCG::new(seed : UInt64) -> LCG {
  { state: seed * 6364136223846793005UL + 1442695040888963407UL, }
}

///|
pub fn LCG::next_u64(self : LCG) -> UInt64 {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  self.state
}

///|
pub fn LCG::next_double(self : LCG) -> Double {
  let v = self.next_u64() >> 11
  v.to_double() / 9007199254740992.0
}
