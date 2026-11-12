# Backend Differential Matrix

MoonBit compiles to four backends (wasm / wasm-gc / js / native). A paper-judgment
test suite that passes **identically on all four** is the strongest cross-platform
correctness signal available: the RFC 8439 ciphertext bytes do not depend on which
backend executes the ARX rounds.

Run it:

```bash
sh scripts/backend_matrix.sh            # from the repo root
```

Cell semantics: `PASS` = at least one test ran and all passed; `FAIL` = non-zero
exit or a failing test; `N/A` = the target compiled but **zero tests ran**
(`moon test` exits 0 with `Total tests: 0` when a package's `supported_targets`
excludes the backend). `N/A` is counted as *not covered*, never as a pass — the
script prints the uncovered cells after the verdict so a green matrix cannot hide
an unexercised backend.

## Verified results (moon 0.1.20261104, 2026-11-09)

| project | wasm | wasm-gc | js | native | judgments exercised |
|---|---|---|---|---|---|
| chacha-mbt | PASS | PASS | PASS | PASS | RFC 8439 full test vectors (byte-exact) |
| cms-mbt | PASS | PASS | PASS | PASS | one-sidedness, row-sum, ε·N window |
| loglog-mbt | PASS | PASS | PASS | PASS | bit-packed registers, family comparison |
| chash-mbt | PASS | PASS | PASS | PASS | monotonicity, smoothness (incl. quickcheck) |
| sais-mbt | PASS | PASS | PASS | PASS | permutation, sortedness, naive oracle |
| codel-mbt | PASS | PASS | PASS | PASS | control-law schedule, servo bounds |
| fpcomp-mbt | PASS | PASS | PASS | PASS | Kahan exactness at extreme scales |
| skiplist-mbt | PASS | PASS | PASS | PASS | geometric distribution, invariants |
| crdt-mbt | PASS | PASS | PASS | PASS | merge commutativity/associativity |
| bwt-mbt | PASS | PASS | PASS | PASS | worked examples, round-trip |
| roaring-mbt | PASS | PASS | PASS | PASS | container encodings, dense/sparse probes |
| eliasfano-mbt | PASS | PASS | PASS | PASS | worked examples, monotone decoding |
| hyperloglog-mbt | PASS | PASS | PASS | PASS | register packing, multi-seed |
| xor16filter | PASS | PASS | PASS | PASS | fingerprint accuracy |
| ziplex-mbt | PASS | PASS | PASS | PASS | lexicon-driven lexing |
| lifeguard-mbt | - | - | - | PASS | suspicion state machine (native-only by design: moonbitlang/async native-stub dependency, declared in moon.pkg `supported_targets`) |
| rqgm-mbt | PASS | PASS | PASS | PASS | Thompson sampling, incomplete beta over stubs |

Status: **16/17 fully consistent across all four backends; 1 project (lifeguard-mbt)
natively scoped by declared dependency constraints — no divergence, only a declared
platform envelope.**
