///|
fn splitmix64(state : UInt64) -> (UInt64, UInt64) {
  let z = state + 0x9E3779B97F4A7C15UL
  let mut x = z
  x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9UL
  x = (x ^ (x >> 27)) * 0x94D049BB133111EBUL
  x = x ^ (x >> 31)
  (z, x)
}

///|
fn main {
  // small range diagnostic
  let seed = 7UL
  let mut n = 0
  while n < 1000 {
    n += 250
    let seen : @hashmap.HashMap[UInt64, Bool] = @hashmap.HashMap([], capacity=2048)
    let h2 = @hyperloglog.HLL::new(10)
    let mut s = seed
    for _ in 0..<n {
      let (_, v) = splitmix64(s)
      s = v
      seen.set(v, true)
      h2.add(v)
    }
    let est = h2.count()
    let truth = seen.length().to_double()
    let err = (est - truth).abs() / truth
    println("n=\{seen.length()} est=\{est} err=\{err}")
  }
  // large range diagnostic
  let h = @hyperloglog.HLL::new(12)
  let mut seed2 = 20260101UL
  let seen : @hashmap.HashMap[UInt64, Bool] = @hashmap.HashMap([], capacity=131072)
  for _ in 0..<100000 {
    let (_, v) = splitmix64(seed2)
    seed2 = v
    seen.set(v, true)
    h.add(v)
  }
  let est = h.count()
  let truth = seen.length().to_double()
  let err = (est - truth).abs() / truth
  println("n=100000 (distinct \{seen.length()}) est=\{est} err=\{err} sigma=\{3.0 * 1.04 / 64.0}")
}
