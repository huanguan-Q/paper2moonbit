import "moonbitlang/core/bigint"

// Recalibration probe (round 19 finding): BigInt-domain contracts are
// unsupported in the logic encoding - expect Error 4207 on this file when
// proving. Presence of this probe keeps the boundary under continuous test.

pub fn bigint_identity_probe(a : BigInt) -> BigInt where {
  proof_ensure: r => r == a,
} {
  a
}
