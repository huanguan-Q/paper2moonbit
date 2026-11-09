///|
async fn main {
  println("== Lifeguard (arXiv:1707.00788) 5-node cluster simulation ==")
  println("n5 dies at t=0; base probe interval 30ms, timeout 20ms, alpha=5, beta=6")
  let t0 = @async.now()
  match @lifeguard.simulate_cluster(
      node_ids=["n1", "n2", "n3", "n4", "n5"],
      dead_node="n5",
      base_probe_interval_ms=30,
      base_probe_timeout_ms=20,
      alpha=5.0,
      beta=6.0,
      budget_ms=5000,
    ) {
    Ok(r) => {
      let wall = @async.now() - t0
      println("all live nodes confirmed n5 failed: \{r.all_confirmed_dead} (by \{r.dead_confirmed_by}/4, in \{wall}ms)")
      println("no healthy node falsely failed:    \{r.no_false_positive}")
      println("peak LHM awareness (backoff):      \{r.awareness_max_seen}")
    }
    Err(msg) => println("simulation error: \{msg}")
  }
}
