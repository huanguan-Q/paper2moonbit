// Paper-criterion tests: numerical core of the ε-best-belief score.
// Reference values computed independently (NR continued fraction, double-checked
// against closed forms: I_0.3(2,5)=0.579825 exact polynomial; BB(1,1)@0.05=0.05 exact).

///|
test "betainc matches reference values" {
  // I_x(a,b) — tolerance 1.0e-9
  assert_eq((betainc(2, 5, 0.3) - 0.5798250000000007).abs() < 1.0e-9, true)
  assert_eq((betainc(3, 3, 0.7) - 0.8369199999999999).abs() < 1.0e-9, true)
  assert_eq((betainc(1, 4, 0.25) - 0.6835937499999991).abs() < 1.0e-9, true)
  assert_eq((betainc(7, 2, 0.9) - 0.81310473).abs() < 1.0e-9, true)
  // symmetric case a=b, x=0.5 is exactly 1/2
  assert_eq((betainc(2, 2, 0.5) - 0.5).abs() < 1.0e-12, true)
  // boundary behavior
  assert_eq(betainc(2, 5, 0.0), 0.0)
  assert_eq(betainc(2, 5, 1.0), 1.0)
}

///|
test "best_belief inverts betainc (roundtrip)" {
  // BB_eps(S,F) = I^{-1}_eps(1+S, 1+F); applying I back must return eps
  let cases : Array[(Int32, Int32, Double, Double)] = [
    // (S, F, eps, reference)
    (4, 9, 0.05, 0.1527176223846629),
    (1, 2, 0.05, 0.09761146288641442),
    (7, 3, 0.10, 0.4892389625934279),
    (0, 0, 0.05, 0.05),
    (14, 5, 0.25, 0.6515597371677786),
  ]
  for case in cases {
    let (s, f, eps, reference) = case
    let bb = best_belief(eps, s, f)
    assert_eq((bb - reference).abs() < 1.0e-9, true)
    // roundtrip: CDF at the quantile recovers eps
    assert_eq((betainc(1 + s, 1 + f, bb) - eps).abs() < 1.0e-9, true)
  }
}

///|
test "best_belief is conservative (Prop. 4 lower bound)" {
  // BB_eps must not exceed the posterior mean (1+S)/(2+S+F) for small eps
  let cases : Array[(Int32, Int32)] = [
    (4, 9),
    (1, 2),
    (7, 3),
    (14, 5),
    (0, 0),
    (99, 1),
  ]
  for case in cases {
    let (s, f) = case
    let bb = best_belief(0.05, s, f)
    let mean = (1.0 + s.to_double()) / (2.0 + s.to_double() + f.to_double())
    assert_eq(bb <= mean, true)
    assert_eq(bb >= 0.0 && bb <= 1.0, true)
  }
}

///|
test "best_belief is monotone in successes" {
  // more successes (same failures) must never lower the conservative score
  for f in [2, 5, 10] {
    for s in [0, 1, 3, 8, 20] {
      let lo = best_belief(0.05, s, f)
      let hi = best_belief(0.05, s + 1, f)
      assert_eq(hi >= lo, true)
    }
  }
}

///|
test "sample_beta is deterministic and in range (Erlang decomposition)" {
  // Beta(i, j) with positive integer parameters: G_i/(G_i+G_j), G_k k-phase Erlang
  let a = LCG::new(42)
  let b = LCG::new(42)
  for _ in [0, 1, 2, 3, 4] {
    let x1 = sample_beta(a, 5, 10)
    let x2 = sample_beta(b, 5, 10)
    assert_eq(x1 == x2, true) // same seed -> same stream
    assert_eq(x1 >= 0.0 && x1 <= 1.0, true)
  }
  // degenerate Beta(1,1) is uniform, still in [0,1]
  let c = LCG::new(7)
  let u = sample_beta(c, 1, 1)
  assert_eq(u >= 0.0 && u <= 1.0, true)
}
