// Paper-criterion tests: archive/erasure/schedule/replacement/harness.
// Judgments come from RQGM §3, App. B Alg. 1, App. F Defs F.1/F.2, Props 2/6, Rems 1/3/7.

///|
test "CMP pools clade outcomes (T-CMP)" {
  // tree: 0 -> [1, 2]; 1 -> [3]; node records: 0:(1s,1f) 1:(3s,1f) 2:(0s,2f) 3:(1s,0f)
  let arch = Archive::new()
  let c1 = arch.add_node(0)
  let c2 = arch.add_node(0)
  let c3 = arch.add_node(c1)
  arch.add_record(0, [], 1)
  arch.add_record(0, [], 0)
  arch.add_record(c1, [], 1)
  arch.add_record(c1, [], 1)
  arch.add_record(c1, [], 1)
  arch.add_record(c1, [], 0)
  arch.add_record(c2, [], 0)
  arch.add_record(c2, [], 0)
  arch.add_record(c3, [], 1)
  arch.recompute()
  // leaf 3: clade = itself -> 1/1
  assert_eq((arch.cmp_score(c3) - 1.0).abs() < 1.0e-12, true)
  // node 1 clade = {1,3} -> succ 4, fail 1
  let (s1, f1) = arch.clade_counts(c1)
  assert_eq(s1, 4)
  assert_eq(f1, 1)
  // node 2 clade = itself -> 0/2
  assert_eq((arch.cmp_score(c2) - 0.0).abs() < 1.0e-12, true)
  // root clade = all -> succ 5, fail 4
  let (sr, fr) = arch.clade_counts(0)
  assert_eq(sr, 5)
  assert_eq(fr, 4)
  assert_eq((arch.cmp_score(0) - 5.0 / 9.0).abs() < 1.0e-12, true)
  // chain boundary: leaf clade contains only itself
  assert_eq(arch.clade(c3).length(), 1)
}

///|
test "UCB-Air gate keeps archive O(N^alpha) (T-GATE)" {
  // gate: expand iff N^alpha >= |T|; with alpha=0.5, N=60 -> N^alpha ~ 7.75
  let h = Harness::run(
    HarnessConfig::new(budget=60, alpha=0.5, eps=0.05, rho=2.0, h=4, seed=11),
  )
  assert_eq(h.archive.nodes.length() <= 9, true)
  // alpha=1.0: gate always open, archive grows nearly every step
  let h2 = Harness::run(
    HarnessConfig::new(budget=40, alpha=1.0, eps=0.05, rho=2.0, h=4, seed=11),
  )
  assert_eq(h2.archive.nodes.length() >= 30, true)
}

///|
test "erasure implements Def. F.2 exactly (T-ERASE-SPEC)" {
  let arch = Archive::new()
  let c1 = arch.add_node(0)
  // record A: depends on slot 0, generated at its epoch 1 -> stale, removed
  arch.add_record(c1, [(0, 1)], 1)
  // record B: depends on slot 0, generated at its epoch 3 -> kept
  arch.add_record(c1, [(0, 3)], 1)
  // record C: depends on slot 1 only -> untouched by slot-0 erasure
  arch.add_record(c1, [(1, 1)], 0)
  // record D: evaluator-independent -> always kept
  arch.add_record(c1, [], 1)
  arch.recompute()
  assert_eq(arch.records.length(), 4)
  let removed = arch.erase_slot(0, 3)
  assert_eq(removed, 1) // only record A
  assert_eq(arch.records.length(), 3)
  // derived stats recomputed from retained records only
  arch.recompute()
  assert_eq(arch.succ[c1], 2)
  assert_eq(arch.fail[c1], 1)
}

///|
test "erasures on disjoint slots commute (Remark 1, T-ERASE-COMMUTE)" {
  // same record set, erase (slot 0 -> 2) and (slot 1 -> 5) in both orders
  fn build() -> Archive {
    let arch = Archive::new()
    let c1 = arch.add_node(0)
    let c2 = arch.add_node(0)
    arch.add_record(c1, [(0, 1)], 1)
    arch.add_record(c1, [(1, 1), (0, 1)], 0) // depends on both -> removed by either
    arch.add_record(c1, [(1, 5)], 1) // fresh for slot 1
    arch.add_record(c2, [], 1)
    arch.add_record(c2, [(0, 2)], 0) // fresh for slot 0
    arch.recompute()
    arch
  }
  let a = build()
  let b = build()
  let ra = a.erase_slot(0, 2)
  let _ = a.erase_slot(1, 5)
  let _ = b.erase_slot(1, 5)
  let rb = b.erase_slot(0, 2)
  assert_eq(ra, 2) // records 1 and 5 stale for slot 0
  assert_eq(rb, 1) // record 2 stale for slot 1
  assert_eq(a.records.length(), b.records.length())
  // same surviving multiset of outcomes
  let oa : Array[Int32] = []
  for r in a.records {
    oa.push(r.outcome)
  }
  let ob : Array[Int32] = []
  for r in b.records {
    ob.push(r.outcome)
  }
  oa.sort()
  ob.sort()
  assert_eq(oa, ob)
}

///|
test "exponential checkpoints reprocess at most rho/(rho-1)*B records (Prop. 6)" {
  // schedule C_B(rho=2, h=1) over budget B=1000: {1,2,4,...,512}
  let cps = checkpoints(2.0, 1, 1000)
  assert_eq(cps, [1, 2, 4, 8, 16, 32, 64, 128, 256, 512])
  // worst case reprocessed at checkpoint c is c; total <= rho*B/(rho-1) = 2B
  let mut total = 0
  for c in cps {
    total += c
  }
  assert_eq(total <= 2000, true)
  // next_checkpoint picks the first checkpoint strictly above N, capped at B
  assert_eq(next_checkpoint(2.0, 1, 0, 1000), 1)
  assert_eq(next_checkpoint(2.0, 1, 3, 1000), 4)
  assert_eq(next_checkpoint(2.0, 1, 600, 1000), 1000) // capped by budget
  // non-trivial rho and h
  assert_eq(checkpoints(3.0, 5, 200), [5, 15, 45, 135])
}

///|
test "uniform checkpoints are quadratic where exponential are linear (Rem. 7)" {
  // uniform every h=10 steps, B=10000: reprocessed = sum_q q*h = h*k(k+1)/2, k=1000
  let k = 10000 / 10
  let uniform_total = 10 * k * (k + 1) / 2
  assert_eq(uniform_total, 5005000)
  // must exceed the exponential bound rho/(rho-1)*B = 2B = 20000 (quadratic >> linear)
  assert_eq(uniform_total > 20000, true)
  // and the exponential schedule over the same budget stays under it
  let cps = checkpoints(2.0, 1, 10000)
  let mut exp_total = 0
  for c in cps {
    exp_total += c
  }
  assert_eq(exp_total <= 20000, true)
}

///|
test "replacement ties favor the incumbent and never worsen the anchor BB (Rem. 3)" {
  // incumbent anchor: 7 successes 3 fails. Challenger with identical counts
  // must NOT replace (tie -> incumbent), and the epoch vector stays put.
  let h1 = Harness::new(
    HarnessConfig::new(budget=20, alpha=0.5, eps=0.05, rho=2.0, h=4, seed=5),
  )
  h1.set_anchor_counts(0, 7, 3)
  let challenger_bb = best_belief(0.05, 7, 3)
  let promoted1 = h1.replacement_rule(0, [(7, 3)]) // challenger ties incumbent
  assert_eq(promoted1, false)
  assert_eq(h1.epochs[0], 1)
  // a strictly better challenger (9/3) IS promoted; its BB >= incumbent's
  let h2 = Harness::new(
    HarnessConfig::new(budget=20, alpha=0.5, eps=0.05, rho=2.0, h=4, seed=5),
  )
  h2.set_anchor_counts(0, 7, 3)
  let promoted2 = h2.replacement_rule(0, [(9, 3)])
  assert_eq(promoted2, true)
  assert_eq(h2.epochs[0], 2)
  assert_eq(best_belief(0.05, 9, 3) >= challenger_bb, true)
  // after replacement the archive keeps criterion consistency (no stale records)
  assert_eq(h2.archive.records.length(), 0)
}

///|
test "harness endpoint is the archive max-BB node and erasure holds (T-HARNESS)" {
  let h = Harness::run(
    HarnessConfig::new(budget=80, alpha=0.5, eps=0.05, rho=2.0, h=8, seed=123),
  )
  // endpoint selection (Alg. 1 L33-35): argmax over nodes of BB_eps(1+S, 1+F)
  let mut best_bb = -1.0
  let mut best_id = -1
  for node in h.archive.nodes {
    let bb = best_belief(
      h.cfg.eps,
      h.archive.succ[node.id],
      h.archive.fail[node.id],
    )
    if bb > best_bb {
      best_bb = bb
      best_id = node.id
    }
  }
  assert_eq(h.endpoint, best_id)
  // criterion consistency: every retained record's tag matches the current epoch (Def. F.1)
  for r in h.archive.records {
    for pair in r.dep {
      let (slot, tag) = pair
      assert_eq(tag == h.epochs_of(slot), true)
    }
  }
  // Prop. 6 accounting: reprocessed records bounded by rho/(rho-1)*B = 2B
  assert_eq(h.reprocessed <= 2 * h.cfg.budget, true)
  // determinism: same seed replays the identical search
  let h2 = Harness::run(
    HarnessConfig::new(budget=80, alpha=0.5, eps=0.05, rho=2.0, h=8, seed=123),
  )
  assert_eq(h2.endpoint, h.endpoint)
  assert_eq(h2.archive.records.length(), h.archive.records.length())
  assert_eq(h2.replacements, h.replacements)
  assert_eq(h2.reprocessed, h.reprocessed)
}

///|
test "node sampling and cell balancing are deterministic and balanced (T-SAMPLE)" {
  let h = Harness::new(
    HarnessConfig::new(budget=30, alpha=0.5, eps=0.05, rho=2.0, h=4, seed=9),
  )
  // least-measured cell: with untouched counters it picks (role 0, task 0);
  // after one evaluation of that cell it moves to the next least-measured
  let arch_node = h.archive.add_node(0)
  h.grow_counters(arch_node)
  let (r1, d1) = h.least_cell(arch_node)
  assert_eq(r1, 0)
  assert_eq(d1, 0)
  h.node_role_cnt[arch_node][0] += 1
  h.node_task_cnt[arch_node][0] += 1
  let (r2, d2) = h.least_cell(arch_node)
  assert_eq(r2, 0)
  assert_eq(d2, 1)
}
