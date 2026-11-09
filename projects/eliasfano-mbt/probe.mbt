// Trivial self-proof: gate the environment (moonbit-proof Step 0).

///|
fn id_double(x : Int) -> Int where {
  proof_require: x >= 0,
  proof_ensure: result => result == 2 * x,
} {
  x + x
}

///|
test "probe runs" {
  assert_eq(id_double(21), 42)
}
