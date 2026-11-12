// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "huanguan-Q/hyperloglog"

version = "0.1.2"

readme = "README.mbt.md"

repository = "github.com/huanguan-Q/paper2moonbit"

license = "Apache-2.0"

keywords = [
  "hyperloglog",
  "cardinality-estimation",
  "probabilistic",
  "sketch",
]

preferred_target = "wasm"

description = "HyperLogLog cardinality estimator (6-bit registers) with multi-seed support."
