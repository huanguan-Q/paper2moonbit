// Numerical core of the ε-best-belief score BBε(a) = I⁻¹_ε(1+S_a, 1+F_a)
// (RQGM §3.1). Regularized incomplete Beta I_x(a,b) via the modified Lentz
// continued fraction (Numerical Recipes betacf), inverted by bisection.
//
// Specialization: in RQGM both Beta parameters are positive integers
// (1+S, 1+F), so the log-beta prefactor uses exact factorial logs — no
// Lanczos approximation needed.

///|
/// ln(n!) exactly for nonnegative integers, by summation.
pub fn log_fact(n : Int32) -> Double {
  let mut acc = 0.0
  for k in 2..<=n {
    acc += @math.ln(k.to_double())
  }
  acc
}

///|
/// Modified Lentz continued fraction for the incomplete Beta (NR betacf).
/// Converges for x in (0,1); caller applies the symmetric switch.
pub fn betacf(a : Int32, b : Int32, x : Double) -> Double {
  let maxit = 300
  let eps = 3.0e-16
  let fpmin = 1.0e-300
  let ad = a.to_double()
  let bd = b.to_double()
  let qab = ad + bd
  let qap = ad + 1.0
  let qam = ad - 1.0
  let mut c = 1.0
  let mut d = 1.0 - qab * x / qap
  if d.abs() < fpmin {
    d = fpmin
  }
  d = 1.0 / d
  let mut h = d
  for m in 1..<=maxit {
    let m2 = 2 * m
    let md = m.to_double()
    let m2d = m2.to_double()
    // even step
    let mut aa = md * (bd - md) * x / ((qam + m2d) * (ad + m2d))
    d = 1.0 + aa * d
    if d.abs() < fpmin {
      d = fpmin
    }
    c = 1.0 + aa / c
    if c.abs() < fpmin {
      c = fpmin
    }
    d = 1.0 / d
    h *= d * c
    // odd step
    aa = -(ad + md) * (qab + md) * x / ((ad + m2d) * (qap + m2d))
    d = 1.0 + aa * d
    if d.abs() < fpmin {
      d = fpmin
    }
    c = 1.0 + aa / c
    if c.abs() < fpmin {
      c = fpmin
    }
    d = 1.0 / d
    let del = d * c
    h *= del
    if (del - 1.0).abs() < eps {
      break
    }
  }
  h
}

///|
/// Regularized incomplete Beta I_x(a,b) for positive integer a, b.
pub fn betainc(a : Int32, b : Int32, x : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  if x >= 1.0 {
    return 1.0
  }
  // bt = x^a (1-x)^b / (a B(a,b)) via exact factorial logs
  let lbt = log_fact(a + b - 1) -
    log_fact(a - 1) -
    log_fact(b - 1) +
    a.to_double() * @math.ln(x) +
    b.to_double() * @math.ln(1.0 - x)
  let bt = @math.exp(lbt)
  // symmetry switch keeps the continued fraction in its convergent region
  if x < (a + 1).to_double() / (a + b + 2).to_double() {
    bt * betacf(a, b, x) / a.to_double()
  } else {
    1.0 - bt * betacf(b, a, 1.0 - x) / b.to_double()
  }
}

///|
/// ε-best-belief score BBε(S,F) = I⁻¹_ε(1+S, 1+F): the ε-quantile of the
/// Beta(1+S, 1+F) posterior — a conservative lower-bound utility (§3.1,
/// Prop. 4). Bisection on the monotone CDF.
pub fn best_belief(eps : Double, succ : Int32, fail : Int32) -> Double {
  let a = 1 + succ
  let b = 1 + fail
  if eps <= 0.0 {
    return 0.0
  }
  if eps >= 1.0 {
    return 1.0
  }
  let mut lo = 0.0
  let mut hi = 1.0
  for _ in 0..<80 {
    let mid = 0.5 * (lo + hi)
    if betainc(a, b, mid) < eps {
      lo = mid
    } else {
      hi = mid
    }
  }
  0.5 * (lo + hi)
}

///|
/// Sample Beta(i, j) for positive integer parameters via the Erlang
/// decomposition: Beta(i,j) = G_i/(G_i+G_j) where G_k is a k-phase Erlang
/// (sum of k unit-rate exponentials, each -ln(U)). Exact for integer
/// parameters; deterministic under the seeded LCG.
pub fn sample_beta(lcg : LCG, i : Int32, j : Int32) -> Double {
  let mut gi = 0.0
  for _ in 0..<i {
    let u = lcg.next_double()
    gi -= if u <= 0.0 { @math.ln(1.0e-300) } else { @math.ln(u) }
  }
  let mut gj = 0.0
  for _ in 0..<j {
    let u = lcg.next_double()
    gj -= if u <= 0.0 { @math.ln(1.0e-300) } else { @math.ln(u) }
  }
  gi / (gi + gj)
}
