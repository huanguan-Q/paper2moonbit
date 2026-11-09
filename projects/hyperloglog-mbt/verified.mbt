///|
// FORMAL-VERIFIED domain (CAPT): pure Int arithmetic + div/mod + for loops.
// Deliberately avoids UInt64 bit-ops (not lowered to the proof layer) and
// Double/@math (not proof-callable) so every function below carries a Z3
// contract: `moon prove` yields verified goals.

///|
/// Position (1-based) of the least significant 1-bit of x, scanning up to
/// `bits` bits; returns bits+1 when x has no set bit in range.
/// Paper role: the rho function of HyperLogLog.
pub fn rho(x0 : Int, bits : Int) -> Int where {
  proof_require: x0 >= 0,
  proof_require: bits > 0,
  proof_ensure: r => r >= 1 && r <= bits + 1,
} {
  let mut result = bits + 1
  let mut x = x0
  for i in 1..=bits {
    if x % 2 == 1 {
      result = i
      break
    }
    x = x / 2
  } where {
    proof_invariant: i >= 1 && i <= bits + 1 && result >= 1 && result <= bits + 1 && x >= 0,
  }
  result
}

///|
/// Register update: monotonically non-decreasing (paper property — a register
/// never forgets an observed rho value). Takes the freshly computed rho value
/// and folds it into the register.
pub fn update_reg(prev : Int, v : Int, bits : Int) -> Int where {
  proof_require: prev >= 0,
  proof_require: prev <= bits + 1,
  proof_require: v >= 1,
  proof_require: v <= bits + 1,
  proof_ensure: r => r >= prev && r >= v && r <= bits + 1,
} {
  if v > prev {
    v
  } else {
    prev
  }
}

///|
/// Register index derived from the low part of a hash value.
pub fn register_of(hash : Int, m : Int) -> Int where {
  proof_require: m > 0,
  proof_require: hash >= 0,
  proof_ensure: r => r >= 0 && r < m,
} {
  hash % m
}
