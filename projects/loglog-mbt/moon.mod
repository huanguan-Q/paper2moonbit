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

name = "huanguan-Q/loglog"

version = "0.1.3"

readme = "README.mbt.md"

repository = "github.com/huanguan-Q/paper2moonbit"

license = "Apache-2.0"

keywords = [
  "cardinality-estimation",
  "loglog",
  "hyperloglog",
  "probabilistic",
]

preferred_target = "wasm"

description = "LogLog and SuperLogLog cardinality estimators with bit-packed registers, plus a HyperLogLog reference for family comparison (Durand & Flajolet, ESA 2003)."
