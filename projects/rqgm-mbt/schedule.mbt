// Exponentially spaced checkpoint schedule C_B(rho, h) = {floor(h*rho^q)}
// with the linear-work bound of Prop. 6, and the uniform-schedule contrast
// of Remark 7 (Theta(B^2/h)).

///|
/// All checkpoints in C_B(rho, h): floor(h*rho^q) for q = 0..Q with
/// h*rho^Q <= B, ascending.
pub fn checkpoints(rho : Double, h : Int32, budget : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  let mut q = 0
  while true {
    let c = (h.to_double() * power(rho, q)).floor().to_int()
    if c > budget {
      break
    }
    out.push(c)
    q += 1
    if q > 62 {
      break // double exponentiation saturates far before any real budget
    }
  }
  out
}

///|
/// rho^q by iterated multiplication (q bounded by the log of the budget,
/// so error accumulation is negligible at double precision).
pub fn power(rho : Double, q : Int32) -> Double {
  let mut acc = 1.0
  for _ in 0..<q {
    acc *= rho
  }
  acc
}

///|
/// The next checkpoint strictly above N, capped at the budget (Alg. 1 L7:
/// b = min{c in C : c > N} ^ B).
pub fn next_checkpoint(
  rho : Double,
  h : Int32,
  n : Int32,
  budget : Int32,
) -> Int32 {
  let mut q = 0
  while true {
    let c = (h.to_double() * power(rho, q)).floor().to_int()
    if c > n {
      if c > budget {
        return budget
      }
      return c
    }
    q += 1
    if q > 62 {
      return budget
    }
  }
  budget
}

///|
/// Uniform checkpoint schedule (every h steps) — the Remark 7 contrast:
/// the cumulative reprocessing burden is Theta(B^2/h), quadratic in B.
pub fn uniform_checkpoints(h : Int32, budget : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  let mut c = h
  while c <= budget {
    out.push(c)
    c += h
  }
  out
}
