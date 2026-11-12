// S4 规格先行：六条论文判据。此时 cms.mbt 尚不存在，预期编译失败（红）。

///|
fn oracle_add(m : Array[(Int32, Int32)], key : Int32, c : Int32) -> Unit {
  for i in 0..<m.length() {
    if m[i].0 == key {
      m[i] = (key, m[i].1 + c)
      return
    }
  }
  m.push((key, c))
}

///|
fn oracle_get(m : Array[(Int32, Int32)], key : Int32) -> Int32 {
  for p in m {
    if p.0 == key {
      return p.1
    }
  }
  0
}

///|
/// T1 小流量流上与精确计数逐项相等
test "T1 exact on small streams" {
  let cms = CMS::new(0.01, 0.01, 42UL)
  let oracle : Array[(Int32, Int32)] = []
  for k in 0..<50 {
    cms.add(k, k % 3 + 1)
    oracle_add(oracle, k, k % 3 + 1)
  }
  for k in 0..<50 {
    assert_eq(cms.estimate(k), oracle_get(oracle, k))
  }
}

///|
/// T2 单侧误差：估计值恒不小于真实值
test "T2 one-sided error" {
  let cms = CMS::new(0.02, 0.01, 7UL)
  let rng = LCG::new(12345UL)
  let oracle : Array[(Int32, Int32)] = []
  for _ in 0..<2000 {
    let k = (rng.next_u64() % 300UL).to_int()
    cms.add(k, 1)
    oracle_add(oracle, k, 1)
  }
  for p in oracle {
    assert_true(cms.estimate(p.0) >= p.1)
  }
}

///|
/// T3 行和守恒：每行计数之和等于流长度
test "T3 row-sum conservation" {
  let cms = CMS::new(0.05, 0.05, 3UL)
  let rng = LCG::new(999UL)
  let mut n = 0
  for _ in 0..<500 {
    cms.add((rng.next_u64() % 50UL).to_int(), 1)
    n = n + 1
  }
  assert_eq(cms.total(), n)
  for row in cms.counters {
    let mut s = 0
    for v in row {
      s = s + v
    }
    assert_eq(s, n)
  }
}

///|
/// T4 εN 误差界：w=ceil(e/eps), d=ceil(ln(1/delta))，跨种子成功率 ≥ 1-delta
test "T4 epsilon-N error bound" {
  let eps = 0.01
  let delta = 0.01
  let n = 20000
  let mut failures = 0
  let seeds : Array[UInt64] = [
    1UL, 2UL, 3UL, 5UL, 8UL, 13UL, 21UL, 34UL, 55UL, 89UL, 144UL, 233UL, 377UL, 610UL,
    987UL, 1597UL, 2584UL, 4181UL, 6765UL, 10946UL,
  ]
  for seed in seeds {
    let cms = CMS::new(eps, delta, seed)
    let rng = LCG::new(seed)
    let oracle : Array[(Int32, Int32)] = []
    for _ in 0..<n {
      let k = (rng.next_u64() % 500UL).to_int()
      cms.add(k, 1)
      oracle_add(oracle, k, 1)
    }
    let bound = (eps * n.to_double()).to_int()
    let mut bad = false
    for p in oracle {
      if cms.estimate(p.0) - p.1 > bound {
        bad = true
      }
    }
    if bad {
      failures = failures + 1
    }
  }
  assert_true(failures.to_double() / seeds.length().to_double() <= delta)
}

///|
/// T5 确定性：同种子同输入 → 同结果
test "T5 determinism" {
  let a = CMS::new(0.05, 0.05, 77UL)
  let b = CMS::new(0.05, 0.05, 77UL)
  for k in 0..<100 {
    a.add(k, 2)
    b.add(k, 2)
  }
  for k in 0..<100 {
    assert_eq(a.estimate(k), b.estimate(k))
  }
}

///|
/// T6 合并：merge 后等价于把两条流喂给同一个 sketch
test "T6 merge equals combined stream" {
  let s1 = CMS::new(0.05, 0.05, 5UL)
  let s2 = CMS::new(0.05, 0.05, 5UL)
  let both = CMS::new(0.05, 0.05, 5UL)
  for k in 0..<60 {
    s1.add(k, 1)
    both.add(k, 1)
  }
  for k in 30..<90 {
    s2.add(k, 2)
    both.add(k, 2)
  }
  s1.merge(s2)
  for k in 0..<90 {
    assert_eq(s1.estimate(k), both.estimate(k))
  }
}
