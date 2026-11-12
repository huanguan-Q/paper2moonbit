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

name = "huanguan-Q/cms"

version = "0.1.2"

readme = "README.mbt.md"

repository = "github.com/huanguan-Q/paper2moonbit"

license = "Apache-2.0"

keywords = [ "sketch", "data-structures", "count-min", "streaming" ]

preferred_target = "wasm"

description = "Count-Min Sketch with point/range/inner-product queries (Cormode & Muthukrishnan 2005). Paper-judgment tests included."
