// The RQGM search harness — Algorithm 1 (App. B), with every LLM-facing
// component replaced by a deterministic seeded stub:
//   EditWorkspace -> edit_stub (ability drift child)
//   TrainEval/ValEval -> Bernoulli(hidden ability * evaluator accuracy)
//   learned evaluators -> fixed anchor accuracies + seeded challenger counts
// The orchestration logic (gate, Thompson-over-CMP node sampling, role/task
// balancing, checkpoint replacement with selective erasure, endpoint
// selection) is the paper's fixed harness and is implemented faithfully.

///|
pub struct HarnessConfig {
  budget : Int32 // B
  alpha : Double // expansion exponent
  eps : Double // best-belief level
  rho : Double // checkpoint base
  h : Int32 // checkpoint min scale
  seed : UInt64
}

///|
pub fn HarnessConfig::new(
  budget~ : Int32,
  alpha~ : Double,
  eps~ : Double,
  rho~ : Double,
  h~ : Int32,
  seed~ : UInt64,
) -> HarnessConfig {
  { budget, alpha, eps, rho, h, seed, }
}

///|
pub struct Harness {
  archive : Archive
  cfg : HarnessConfig
  epochs : Array[Int32] // epoch vector j, one entry per evaluator slot
  eval_acc : Array[Double] // stub evaluator accuracy per slot
  anchor_succ : Array[Int32] // anchor ground-truth counts per slot
  anchor_fail : Array[Int32]
  rng : LCG
  mut n_evals : Int32 // N
  node_role_cnt : Array[Array[Int32]] // per node, per role
  node_task_cnt : Array[Array[Int32]] // per node, per role*task cell
  mut reprocessed : Int32 // Prop. 6 exposure accounting
  mut replacements : Int32
  hidden : Array[Double] // stub node abilities
  mut endpoint : Int32
}

///|
const N_ROLES : Int32 = 2 // role 0 evaluator-dependent (slot 0), role 1 fixed

///|
const N_TASKS : Int32 = 3 // tasks per role

///|
pub fn Harness::new(cfg : HarnessConfig) -> Harness {
  let h = {
    archive: Archive::new(),
    cfg,
    epochs: [1],
    eval_acc: [0.8],
    anchor_succ: [0],
    anchor_fail: [0],
    rng: LCG::new(cfg.seed),
    n_evals: 0,
    node_role_cnt: [],
    node_task_cnt: [],
    reprocessed: 0,
    replacements: 0,
    hidden: [0.5],
    endpoint: 0,
  }
  h.grow_counters(0)
  h
}

///|
pub fn Harness::epochs_of(self : Harness, slot : Int32) -> Int32 {
  self.epochs[slot]
}

///|
pub fn Harness::grow_counters(self : Harness, node : Int32) -> Unit {
  // ensure parallel counter arrays extend to cover node index `node`
  while self.node_role_cnt.length() <= node {
    self.node_role_cnt.push([0, 0])
    self.node_task_cnt.push([0, 0, 0, 0, 0, 0])
    self.hidden.push(0.0)
  }
}

///|
/// UCB-Air expansion gate (§3.3): expand a new node iff N^alpha >= |T|.
pub fn Harness::expand_gate(self : Harness) -> Bool {
  @math.pow(self.n_evals.to_double(), self.cfg.alpha) >=
  self.archive.nodes.length().to_double()
}

///|
/// Thompson sampling over clade outcomes: sample Beta(1+n_C_succ, 1+n_C_fail)
/// per node, return the argmax (§3.1, §3.3 node-level HGM choice).
pub fn Harness::sample_node_cmp(self : Harness) -> Int32 {
  let mut best_sample = -1.0
  let mut best_id = 0
  for node in self.archive.nodes {
    let (s, f) = self.archive.clade_counts(node.id)
    let x = sample_beta(self.rng, 1 + s, 1 + f)
    if x > best_sample {
      best_sample = x
      best_id = node.id
    }
  }
  best_id
}

///|
/// LeastMeasuredCell (Alg. 1 L18): the least-evaluated eligible role-task
/// cell of node a. Sampling with replacement keeps every task eligible.
pub fn Harness::least_cell(self : Harness, node : Int32) -> (Int32, Int32) {
  let mut best_r = 0
  let mut best_d = 0
  let mut best_cnt = 1000000000
  for r in 0..<N_ROLES {
    for d in 0..<N_TASKS {
      let cnt = self.node_task_cnt[node][r * N_TASKS + d]
      if cnt < best_cnt {
        best_cnt = cnt
        best_r = r
        best_d = d
      }
    }
  }
  (best_r, best_d)
}

///|
/// Stub EditWorkspace: child ability drifts around the parent's, clamped.
pub fn Harness::edit_stub(self : Harness, parent : Int32) -> Int32 {
  let drift = self.rng.next_double() - 0.5
  let mut ability = self.hidden[parent] + drift * 0.2
  if ability < 0.05 {
    ability = 0.05
  }
  if ability > 0.95 {
    ability = 0.95
  }
  let child = self.archive.add_node(parent)
  self.grow_counters(child)
  self.hidden[child] = ability
  child
}

///|
/// One validation evaluation (Alg. 1 L19-20): Bernoulli stub outcome,
/// recorded with the criterion tags of the current epoch vector.
pub fn Harness::val_eval(
  self : Harness,
  node : Int32,
  role : Int32,
  task : Int32,
) -> Unit {
  let p = if role == 0 {
    self.hidden[node] * self.eval_acc[0]
  } else {
    self.hidden[node]
  }
  let outcome = if self.rng.next_double() < p { 1 } else { 0 }
  self.node_role_cnt[node][role] += 1
  self.node_task_cnt[node][role * N_TASKS + task] += 1
  let dep = if role == 0 { [(0, self.epochs[0])] } else { [] }
  self.archive.add_record(node, dep, outcome)
  self.n_evals += 1
}

///|
/// Stub TrainEval: lineage evidence only — a few training outcomes that must
/// NOT influence search utility, so they are recorded evaluator-independent
/// (dep = []) and only feed clade statistics like any other record.
pub fn Harness::train_stub(
  self : Harness,
  node : Int32,
  rounds : Int32,
) -> Unit {
  for _ in 0..<rounds {
    let outcome = if self.rng.next_double() < self.hidden[node] { 1 } else { 0 }
    self.archive.add_record(node, [], outcome)
  }
  self.archive.recompute()
}

///|
pub fn Harness::set_anchor_counts(
  self : Harness,
  slot : Int32,
  s : Int32,
  f : Int32,
) -> Unit {
  self.anchor_succ[slot] = s
  self.anchor_fail[slot] = f
}

///|
/// Ground-truth best-belief replacement rule (Alg. 1 L22-31, App. F.2.1):
/// score incumbent and challengers by BB_eps on anchor counts; promote only
/// a strict maximizer — ties favor the incumbent (Remark 3). On promotion:
/// advance the slot epoch, erase the displaced slot's records, recompute.
pub fn Harness::replacement_rule(
  self : Harness,
  slot : Int32,
  challengers : Array[(Int32, Int32)],
) -> Bool {
  let eps = self.cfg.eps
  let inc_bb = best_belief(eps, self.anchor_succ[slot], self.anchor_fail[slot])
  let mut best_s = self.anchor_succ[slot]
  let mut best_f = self.anchor_fail[slot]
  let mut best_bb = inc_bb
  let mut changed = false
  for ch in challengers {
    let (s, f) = ch
    let bb = best_belief(eps, s, f)
    if bb > best_bb {
      best_bb = bb
      best_s = s
      best_f = f
      changed = true
    }
  }
  if changed {
    // exposure accounting: slot-dependent records present before erasure
    let mut exposed = 0
    for r in self.archive.records {
      for pair in r.dep {
        let (s, _) = pair
        if s == slot {
          exposed += 1
        }
      }
    }
    self.reprocessed += exposed
    let new_epoch = self.epochs[slot] + 1
    let _ = self.archive.erase_slot(slot, new_epoch)
    self.archive.recompute()
    self.epochs[slot] = new_epoch
    self.anchor_succ[slot] = best_s
    self.anchor_fail[slot] = best_f
    // stub: a promoted challenger is a stricter evaluator
    self.eval_acc[slot] = self.eval_acc[slot] * 0.85
    self.replacements += 1
  }
  changed
}

///|
/// Checkpoint step (Alg. 1 L22-31): challenger anchor counts are drawn from
/// the seeded RNG (stub for co-evolved challenger evaluators).
pub fn Harness::checkpoint(self : Harness) -> Unit {
  for slot in 0..<self.epochs.length() {
    let cs = (self.rng.next_u64() % 12UL).to_int()
    let cf = (self.rng.next_u64() % 12UL).to_int()
    let _ = self.replacement_rule(slot, [(cs, cf)])
  }
}

///|
/// Endpoint selection (Alg. 1 L33-35): the archive node with the highest
/// node-level eps-best-belief on its own records.
pub fn Harness::select_endpoint(self : Harness) -> Int32 {
  let mut best_bb = -1.0
  let mut best_id = 0
  for node in self.archive.nodes {
    let bb = best_belief(
      self.cfg.eps,
      self.archive.succ[node.id],
      self.archive.fail[node.id],
    )
    if bb > best_bb {
      best_bb = bb
      best_id = node.id
    }
  }
  best_id
}

///|
/// Algorithm 1 in full: init -> CMP-guided search between checkpoints ->
/// anchor-only evaluator replacement at checkpoints -> endpoint selection.
pub fn Harness::run(cfg : HarnessConfig) -> Harness {
  let h = Harness::new(cfg)
  h.train_stub(0, 2) // seed lineage evidence only (Alg. 1 L4)
  while h.n_evals < cfg.budget {
    let b = next_checkpoint(cfg.rho, cfg.h, h.n_evals, cfg.budget)
    while h.n_evals < b {
      if h.expand_gate() {
        let parent = h.sample_node_cmp()
        let _ = h.edit_stub(parent)
      }
      let a = h.sample_node_cmp()
      let (r, d) = h.least_cell(a)
      h.val_eval(a, r, d)
    }
    h.checkpoint()
  }
  h.endpoint = h.select_endpoint()
  h
}
