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

name = "huanguan-Q/fpcomp"

version = "0.1.1"

readme = "README.mbt.md"

repository = "github.com/huanguan-Q/paper2moonbit"

license = "Apache-2.0"

keywords = [ "floating-point", "kahan", "compensated-summation" ]

preferred_target = "wasm"

description = "Floating-point compensated arithmetic: FastTwoSum/TwoSum/Sterbenz/Kahan (Goldberg, 1991) with extreme-scale judgments."
