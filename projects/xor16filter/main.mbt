///|
/// Demo: build an xor16 filter over splitmix-generated keys and probe it.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let rng = Ref(42UL)
  let keys = Array(capacity=1000)
  for _ in 0..<1000 {
    keys.push(@xor16filter.splitmix64_next(rng))
  }
  let f = match @xor16filter.build(keys) {
    Ok(f) => f
    Err(msg) => {
      println("build failed: \{msg}")
      return
    }
  }
  let mut members = 0
  let mut probes = 0
  let mut false_positives = 0
  for key in keys {
    if f.contains(key) {
      members += 1
    }
  }
  for _ in 0..<1_000_000 {
    probes += 1
    if f.contains(@xor16filter.splitmix64_next(rng)) {
      false_positives += 1
    }
  }
  println("built xor16 filter over \{keys.length()} keys")
  println("members recognized: \{members}/\{keys.length()}")
  println("false positives: \{false_positives}/\{probes} probes")
}
