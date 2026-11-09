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

name = "huanguan-Q/bwt"

version = "0.1.0"

readme = "README.mbt.md"

repository = "github.com/huanguan-Q/paper2moonbit"

license = "Apache-2.0"

keywords = [ "bwt", "compression", "strings" ]

preferred_target = "wasm"

description = "Burrows-Wheeler Transform pipeline: BWT/MTF/zero-run encoding with end-to-end round-trip (Burrows & Wheeler, SRC-RR-124)."
