<!-- last_updated: 2026-11-03 -->
<!-- ref: class=P1; threshold=常驻; load_when=进入 S3/S5 前必读 -->

# MoonBit 语境知识库（防幻觉卡片）

依据：IEEE TSE《No Resource, No Benchmarks, No Problem?》证实模型对 MoonBit 的失败主要是**语法错误**（Rust 风味幻觉），few-shot/文档注入增益显著。本文件即注入语料。以官方 moonbitlang.com 文档与本机工具链输出为准；本卡片过期时以 `moonbit-orientation` 查证结果为准。

## 工具链版本实测事实（moon 0.1.20261028，2026-11-03 试跑 xor16filter/roaring/eliasfano 实证）

以下语法事实来自真实编译反馈，生成代码前先对照，可省掉整轮 check 报错：

- **断言/快照**：`assert_eq(a, b)`、`inspect(x, content="...")` —— **`!` 后缀调用语法已移除**（`assert_eq!(..)` 直接 parse error）。`inspect` 第二参数是命名参数 `content?`，布尔断言直接用 `assert_eq(x, true)` 更顺。
- **构造器**：`Ref(x)` 而非 `Ref::new(x)`；`Array(capacity=n)` 而非 `Array::new(capacity=n)`（两者均触发 deprecated 警告）。
- **方法定义**：公开方法写 `pub fn Type::method(self : T, ..)`；`pub fn method(self : T, ..)` 触发 deprecated_syntax 警告。
- **可见性**：不出现在公开签名中的类型标 `priv struct`，否则 missing_priv 警告。
- **黑盒测试（`*_test.mbt`）**：经 `@pkg` 别名访问公开 API；**不能调用 `Result` 的 `is_ok/is_err` 方法**（用 `match { Ok.. Err.. }`）；未限定直接调用本包函数触发 test_unqualified_package 警告 → 写 `@pkg.fn`。白盒 `*_wbtest.mbt` 在包作用域内可直接用内部函数。
- **清单格式**：新工具链为 TOML 风格 `moon.mod` / `moon.pkg`（非 json）；跨包调用需在 `moon.pkg` 的 `import {}` 声明，代码内不写 import。
- **块分隔**：每个顶层项前加 `///|`（工具链依赖它分块）。
- **本地权威文档**：`~/.moon/AGENTS.md`（语言基础+项目布局）——S3 语境注入第一步先读它，再查 mooncakes。
- **UInt64**：`1UL` 字面量；`^ & | << >>` 位运算可用；乘法回绕；`to_int()` 截断转换存在。
- **测试命令**：`moon test`；输出 `Total tests: N, passed: X`；失败带 diff（`-got +want`）。

### 第三轮试跑新增（eliasfano，2026-11-03）

- **⚠ wasm 移位按 64 取模（编译器查不出的死循环源）**：`q >> 64 == q`、`x << 64 == x`。任何 `while (q >> (l + 1)) > 0` 这类含变量移位的循环必须加上界守卫（如 `l < 63 &&`），否则运行期死循环且 `moon test` **无任何输出地挂死**（eliasfano 的 floor_log2 实证，挂在 `[0xFFFFFFFFFFFFFFFF]` 用例）。测试挂死先排查变量移位循环，再查别的。
- **`mut` 参数不支持**：`fn f(mut x : T)` parse error。参数不可变，函数体内用 `let mut y = x`。
- **复合赋值 `|=` `&=` 不支持**（parse error）：写 `x = x | y`。
- **`!` 仅是 Bool 逻辑非**；按位取反没有前缀运算符——用 xor 恒等式 `a & ~b == a ^ (a & b)`，或查 core 的位反 API。
- **`raise String` 不合法**：`Type String is not an error type`（[4127]）。快速失败用 `abort("msg")`（`fn[T] abort(String) -> T`，多态返回）或返回 `Result`；错误类型须继承 Error。
- **整数转换**：`Int::to_uint64()`、`UInt64::to_int()` 存在；UInt32→UInt64 **没有** `reinterpret_as_uint64`，用 `.to_uint64()`。
- **迭代**：`for i, x in arr`（索引+值双绑定）可用。

## moon prove 形式化验证实测（2026-11-03 eliasfano 试跑，重要边界）

- **环境开箱即用**：Why3 工具链内置（`~/.moon/lib/why3` 存在即满足，无需 opam）；外部求解器装好 z3 或 alt-ergo 后 `moon prove` 直接工作。
- **门禁自证流程有效**：独立探针包（`proof_enabled = true` + 一个平凡 `where { proof_require, proof_ensure }` 契约）→ `moon prove <dir>` 输出 `Succeeded: N goals proved` 即通过。
- **⚠ 致命限制：UInt64 全部位运算（`>>` `<<` `&` `|` `^`）未下发证明层**——contracted 函数体与 `#proof_pure` 函数体均报 `unsupported expression`（E4207 族）。位级不变量**无法直接证明**（实测五探针全挂）。
- **可行路径：位结构 → 数学整数建模**。在 `.mbtp` 里用 `/ % *` 写 div/mod 恒等式（`b = 2^l` 时正是 EF 的 encode/decode 语义），Z3 秒证。示例见 eliasfano-mbt/proofmodel/verify.mbtp（2 goals proved）。
- **proof_enabled 包内含 Array 的 struct 下发失败**：WhyML 报 `unbound type symbol 'array'` → **证明放独立纯证明包**（只有 .mbtp，或无数组引用的 .mbt），主包不开 proof_enabled。
- **`.mbtp` 语法**：lemma 的 `proof_ensure` **不接受 `&&`**（parse error 3002），拆成多条断言或只保留关键部分；predicate 体内 `&&` 可用。
- **过滤器形式**：`moon prove <path>` 接受文件系统路径（如包目录名或 `.`）；`moon prove huanguan-Q/xxx` 这种包名形式报 Failed to canonicalize。
- `moon explain --diagnostic <code>` 可查官方解释，但码文与实际错误可能不完全对口（如 E4207 文档写 invalid_predicate，实际命中的是 unsupported expression）。

## 第四轮试跑新增（ZipLex 词法引擎，arXiv:2510.18479，2026-11-03）

- **String 索引返回 UInt16**：`s[i]` 是 UTF-16 码元不是 Char——`s[i].to_char()` 返回 `Char?`（需 match）。切片 `s[a:b]` 返回 StringView，转 owned 用 `.to_owned()`（`.to_string()` 已弃用）。
- **HashMap**（`moonbitlang/core/hashmap`）：构造 `HashMap([], capacity=N)`（`::new(capacity=)` 弃用）；`set(k, v)` / `get(k) -> V?`；键需 `Hash + Eq`。moon.pkg 需 `import { "moonbitlang/core/hashmap" @hashmap, }`（**多行 import 逗号分隔**，无逗号 parse error）。
- **derive 的隐式方法提升已弃用**：`derive(Eq, Hash, @debug.Debug)` 会触发 implicit_impl_as_method 警告，需显式补三行：`pub extend T with Eq::{equal, not_equal}` / `pub extend T with Hash::{hash, hash_combine}` / `pub extend T with @debug.Debug::{to_repr}`。wbtest 里 `assert_eq(自定义类型, ..)` 要求该类型 derive `@debug.Debug`。
- **pub struct 字段默认公开**（字段前再加 pub 报 redundant_modifier）。
- 命名参数调用语法是 `f(label=value)`；`\x00` 弃用 → `\u{0000}`；`not(x)` 弃用 → `!x`。
- **测试期望值要写"smart constructor 折叠后"的形式**：如 `D_a(a*) = concat(REps, a*)` 折叠为 `a*`——期望写成未折叠形式会假失败（本轮实证）。

## 第五轮试跑新增（Lifeguard 网络协议，arXiv:1707.00788，2026-11-03，moonbit-async 路由实测）

- **async 环境配方**：`moon add moonbitlang/async`；async 仅 native/llvm（wasm1/js 子集），moon.mod 设 `preferred_target = "native"`，moon.pkg 加 `supported_targets = "+native"`。包内直接 `import { "moonbitlang/async" }` 即可，**`async test "..."` 不需要 test-import 段**（官方样例无此段，写了反而 parse error）。
- **`try?` 语法已移除**：报错提示改用 `try Ok(expr) catch {..}`——更简单的做法是给函数签名加 `raise`，然后直接 `match queue.try_get() { Some(x) => ..; None => .. }`（`Queue::try_get/try_put` 返回 `X? raise`，None=空队）。
- **`@async.now()` 返回 Int64**：与 Int 毫秒参数比较要 `.to_int64()`；所有时间戳运算注意 Int64/Int 混用。
- **`TaskGroup::spawn()` 返回 Task 不可隐式忽略**：写 `let _ = tg.spawn(...)`；闭包要显式 `async fn() {..}`；`with_task_group(async fn(tg) {..})`。
- **`Option::unwrap(default)` 双参形式不存在**：`unwrap` 只收 1 参（panic 语义），带默认值自己写 `fn[T] opt_or(v : T?, d : T) -> T`。
- **跨包构造 enum 必须 `pub(all) enum`**（`pub enum` 是 read-only，外部包不能创建构造器值）；`assert_eq` 比较自定义 enum/struct 需 `derive(@debug.Debug)` 且 moon.pkg import `moonbitlang/core/debug` + extend 三件套。
- **入口语法**：`fn main { ... }`（无参数无返回注解）；async 程序用 `async fn main { ... }`。
- **高价值教训——envelope 寻址 bug**：仿真消息总线里 `put(to, ...)` 的目标参数没接进 struct 字段（struct literal 按字段名绑定，形参名 vs 字段名错位），症状是"测试跑得动但集成断言全挂"——编译器只有 unused_variable 'to' 一条弱提示，**struct literal 传参必须逐字段核对**。
- gossip 类协议实现防环必需 per-origin 去重（`HashMap[String, Bool]` 记 `origin|tag|about|inc`），flood 转发排除上一跳；独立怀疑计数用 origin 集合（对应论文 C 的语义）。

## 第六轮试跑新增（HyperLogLog，DMTCS 2007，instinct-driven-moonbit 主线实测 2026-11-03）

- **CAPT 分层实测成立**：FORMAL 域（Int+div/mod+for 循环+where contract）`moon prove` 3 goals proved 全真验证；Double/@math.ln 估计器按预期降级 RUNTIME。moon.pkg 须 `proof_enabled = true`（**2026-11-12 校准**：17 项目实测 8 处均为该写法；旧记录 `options("proof-enabled": true)` 已废），判据三件套 rc==0 + Summary 行 + goals>0。
- **新发现——Why3 保留字撞参数名**：函数参数名 `old` 让生成的 WhyML syntax error（Why3 的 `old` 指入口状态）——改名即全通。参数命名避开 old/result 类逻辑侧词。
- **循环不变量语法（实测）**：技能文档的 `for...nobreak {}` 关键字在本工具链不存在；正确形态是 `for i in a..=b { .. } where { proof_invariant: ... }`。**不变量必须含循环变量自身的界**（只给结果界会 postcondition timeout；补 `i >= 1 && i <= bits+1` 后通过）。
- **函数级 contract 是 goals 的前提**：只有循环 where 无函数 require/ensure 时 prove 输出 0 goals（零验证，W6 变体）。
- **moon.pkg 测试专用导入**：`import { "moonbitlang/core/hashmap" } for "test"`——根包普通 import 不算测试引用（会报 unused），删了又报 not_imported，正确键是 `for "test"` 段。
- **最重要的方法论发现——Z3 证明的语义盲区**：`update_reg` 首版把"已算好的 rho 值"当"原始 hash"又做了一次 rho（双重 rho），**contract 自洽、Z3 全证、运行期导致估计系统性偏低 5 倍**——只有论文判据测试（大基数误差界）抓到。结论：**形式化证明验证实现与 contract 的一致性，不验证 contract 与论文语义的一致性**；CAPT 流程中"论文判据级运行时测试"不可省略，两者正交。
- probe 先行有效：单函数先证通再铺开，避免三个函数一起 debug 证明失败。

## 第七轮试跑新增（CRDT，Shapiro RR-7687，2026-11-03）

- **⚠ `.mbtp` 逻辑连接词边界（本轮核心发现）**：`proof_require`/`proof_ensure` 子句内 **`||` 是 parse error**；`&&` 在 ensure 同样非法（eliasfano 结论再实证）；Unicode `∨`（U+2228）**词法不识别**（unrecognized character 3001）。谓词体内 `&&` 合法、但**含 `||` 析取的 predicate 会让依赖它的 VC timeout**（max_comm 实证：对称平凡命题超时）。
- **✅ 析取的无解药编码——多项式恒等**：`m == a || m == b` 改写为 `(m - a) * (m - b) == 0`（变量乘变量，非线性但 Z3 秒证）。用此编码 max 的交换/幂等/结合三律 3 goals 一次全绿（crdt-mbt/proofmodel/verify.mbtp）。
- **lemma-as-∀ 模式**：assoc 类"两分组一致"性质用中间量升 lemma 参数 + predicate 前提约束（`is_max(a,b,m1) ∧ is_max(m1,c,r1) ⊢ r1==r2`），Z3 直接收敛，无需量词。
- **moon prove 有目标级缓存**：改一处只重证部分 goal；强制全量重证需 `rm -rf _build/verif`（增量 summary 的 goals 数 ≠ 全部 lemma 数，勿据其断言覆盖）。
- **OR-Set 语义完整性 bug（第七轮"证明≠语义"变体）**：remove 只把观察到的 tags 写入墓碑、**未从本地活集剥离**——墓碑记录了但 lookup 仍 true，症状"remove 后本地状态不变"。修复：remove 必须同时删除本地 pairs。教训同 envelope/双重 rho：**写路径的每一步状态变更都要问"抽象状态是否同步反映"**。
- **测试算术错误两连**：向量化 counter 的期望值必须逐项归属副本（reps[2] 吸收了副本 1/3 后是 [0,5,5,5]=15 不是 20）——多副本测试先在纸上画向量再写期望。
- 结构体字段 shorthand `{ pairs: [], tombstones: [], next: 0, base }` 可用；`i += 1` 合法（`|=` `&=` 仍非法）。

## 第八轮试跑新增（RQGM 搜索 harness，Iacob et al. 2026，2026-11-03）

- **数值方法路由首次实测**（逆正则化不完全 Beta：连分式 betacf + 二分逆 + 整数参数阶乘对数 prefactor）：Double 域数值核心 + 14/14 测试一次全绿。scipy 缺装时用纯 Python NR 算法生成参考值，闭式特例（I_0.3(2,5)=0.579825、BB(1,1)@ε=ε）交叉验证。
- **证明层 `&&` 边界精化（修正第七轮结论）**：`&&` 在 **predicate 体内合法**（`predicate p { a >= 0 && b >= 0 }` 可解析可证），**仅在 proof_require/proof_ensure 子句里非法**。合法解法：复合条件封装进 predicate，再 `proof_require: p(x)`。
- **测试文件黑盒/白盒语义**：`*_test.mbt` 是**黑盒**（独立包，需 `@模块名` 别名引用，函数须 pub）；`*_wbtest.mbt` 是**白盒**（同包直访，priv 可见）。同包结构化测试用 wbtest 免别名最省事。
- **裸 `assert` 不存在**（unbound + reserved keyword 双报错），只有 `assert_eq`/`assert_not_eq`；布尔条件写 `assert_eq(cond, true)`。
- **`Double` 无 `.log()`/`.exp()` 方法**——用 `@math.ln`/`@math.exp`（moon.pkg 需 import `"moonbitlang/core/math"`）；`.abs()` 方法存在。`Int`→`Double` 是 `to_double()`（不是 `todouble()`）；`UInt64` 也有 `to_double()`。
- **科学计数法字面量必须带小数点**：`1e-9` parse error → `1.0e-9`。
- **顶层常量用 `const NAME : Int = 2`**（大写 `let NAME` 报错提示用 const）；`Int::MAX_VALUE()` 不存在，用字面量。
- **零警告惯用法（单包项目）**：`priv struct` + 白盒测试引用会报 unused（主包视角测试不计入使用方）——统一 `pub struct`（敏感字段 `priv mut`）+ 对外函数 `pub`，一次清零。
- **Stub 化协议**（LLM/RNG 依赖论文的通用配方）：agent/evaluator 藏在确定性种子 stub 后（LCG + 固定精度 Bernoulli），harness 纯逻辑全量测试 + 种子重放确定性断言（同 seed 两次 run 的 endpoint/records/reprocessed 全等）。
- **RQGM 性质测试直接映射论文命题**：Def.F.2 擦除语义、Remark 1 顺序无关（双槽两序擦除保留集相等）、Prop.6 线性界（Σ 检查点 ≤ ρB/(ρ−1)）、Remark 7 对照（均匀检查点 Θ(B²/h) 数值演示 > 2B）、Remark 3 平局 incumbent 胜。论文伪代码（Alg.1）逐行翻译 + stub 接口是协议类论文降级实现的通用骨架。

## 第九轮试跑新增（BWT 压缩管线，Burrows & Wheeler SRC-RR-124，2026-11-08）

- **字符串 API 实测**：遍历取字符用 `for ch in s { ch.to_int() }`——`s.char_at(i)` **不存在**；`StringBuilder::new()` 弃用 → `StringBuilder()`；`Char::from_int(c)` 弃用 → `Int::unsafe_to_char(c)`（`Int::to_char` 签名不同，直接 `.to_char()` 报 type mismatch）。
- **range 运算符末端禁复合表达式**：`for k in 0..<n - 1` parse error → 先 `let lim = n - 1` 再 `for k in 0..<lim`。
- **const 大写规则两次踩坑**（第七/九轮均中招）：顶层 `let UPPER : Int = ...` 报错提示用 `const UPPER`——生成代码时顶层不可变常量一律直接写 `const`。
- **"论文 example 即测试判据"配方再次全胜**：'abraca'→L='caraab'/I=1、T=(4 0 5 1 2 3)、MTF R=(2 1 3 1 0 3) 三个手工验证的 worked example 全部一次命中（11/11 首轮全绿）。S1 阶段先在纸上验算 T/P/C 再写进测试，是字符串算法类的最高性价比判据来源。
- **§4.2 伪代码逐行翻译配方**：论文给出的过程式伪代码（`for i := 0 to N-1 do P[i] := C[L[i]]; C[L[i]] += 1`）可直接逐行译成 while 循环，变量名一一对应，零语义偏差——比从数学描述重推更可靠。
- 原论文 PDF 原链失效时的镜像序：JHU 课程页（cs.jhu.edu/~langmea/resources/）比 CiteSeerX 稳定；archive.org bitsavers 有扫描版兜底。

## 第十轮试跑新增（Skip Lists，Pugh CACM 1990，2026-11-08）

- **⚠ 证明 Timeout 诊断配方（本轮核心发现）**：proof_ensure 后件在参数无约束时不成立时，Z3/Alt-Ergo 表现为 **Timeout 而非反例**——读 `_build/verif/*.proof.json` 的 task_pretty 逐 axiom 排查（Ensure 序号对应 lambda 展开的位置），发现缺 `max_level >= 1` 前提；补 `proof_require` 后秒证。**Timeout ≠ 求解器抖动，先查契约前提完备性**。
- **proof_ensure 精确边界（修正第七轮）**：裸布尔子句内 `&&` 非法，但 **lambda 形式合法**：`proof_ensure: r => r >= 1 && r <= max`（HLL/跳表双实证）。复合结果约束一律写 lambda。
- **MoonBit struct 无内建引用相等**（不实现 Eq trait，`!=` 直接报错）——引用身份用 **id 字段模式**：节点带唯一 id（NIL=-1、header=0、自增分配器），所有链上比较用 `.id`。
- **有序字典语义先对齐 oracle**：跳表重复 key = 更新不重复插入（Fig.4 `x->value := newValue` 分支）——oracle 测试若允许重复会在首轮失败。写 oracle 前先从论文伪代码确认重复语义。
- **方法名与字段同名冲突**：`SkipList::level` 与字段 `level` 冲突报"no method level"→ 方法改名 `current_level`。
- **位流生成几何分布**（p=1/2）：run = 连续 0 位计数，level = 1+min(run, MaxLevel−1)，P(level≥k)=p^(k−1) 与 Fig.5 循环同分布——论文明文建议位流方案，恰好把封顶逻辑抽成可证纯函数 cap_level。
- 期望代价经验判据写法：n=4096、p=1/2 → L(n)/p+1/(1−p)+1 ≈ 27，种子固定取宽松窗口 [15,60]（论文 §Analysis 判据落地模式）。

## 第十一轮试跑新增（Consistent Hashing，Karger STOC'97，2026-11-08）

- **证明层 mod 推理可用（能力边界扩展）**：`x % ring >= 0 && x % ring < ring` 对 require `x >= 0 && ring >= 1` 直接可证（4 goals 一次全过）——div/mod 在 FORMAL 域确实受支持，此前只记录过 eliasfano 的 div 恒等式。
- **assert_eq/abort 边界**：`assert_eq` 是 error 类型函数，只能在测试块内用；运行时卫语句用 `if cond { abort("msg") }`。
- **论文构造 vs 工程变体要分清**：Karger 1997 的一致性哈希是"单位区间最近点"（桶复制 K 个点，f^V(i)=argmin|r_B−r_I|），不是工程界流行的环形顺时针后继——按论文实现前先读构造节，别把常识变体当论文定义。
- **论文固有不确定性判据的种子化落地**：balance/smoothness 是高概率命题，取"常数因子窗口"（≤4/|V|）+ 固定种子使其确定性化；单调性/成员资格是全称命题，逐对断言即可。
- **重复定义警告跨文件生效**：顶层 const 在同包多文件中只能声明一次（RING 在 mix.mbt 与测试文件重复 → 4051）。
- moon 工具链 0.1.20261028 → **0.1.20261102**（第十轮到第十一轮间升级，全部既有配方无需改动即通过——配方稳定性实证）。

## 第十二轮试跑新增（Count-Min Sketch，Cormode-Muthukrishnan J.Algorithms 2005，2026-11-08）

- **概率判据的"全称/窗口"二分法（本轮成型）**：论文定理拆成两类判据——单侧不等式（est ≥ true）是构造必然，可全称精确断言；概率界（est ≤ true + εN）固定种子后取常数因子窗口（≤3εN）+ 重 hitter 相对误差窗口（≤5%）。先判断据属于哪类再写测试，避免把概率命题写成脆弱精确断言。
- **行和守恒是最强免费判据**：Update 过程的线性性 ⇒ 任一行计数和恒等于流总量——精确、全称、零成本，比误差界更早抓住实现 bug。概要类数据结构先找这类"线性不变量"。
- **保守更新非论文正文定义**：CMS 期刊版没有 CU 算法（社区 Estan-Varghese 谱系，HandWiki 公式化：est=min 后 count←max{count, est+c}）——实现社区变体必须在偏差声明里写明出处，不能冒充论文算法定义。
- **PDF 镜像查找序补强**：作者学术主页（cs.ox.ac.uk 用的相对路径 ../papers/）→ 先抓 HTML 页 grep `href.*pdf` 再拼绝对路径，比猜文件名可靠；ScienceDirect PII 直链被反爬；Wayback Machine 对深路径存档率低。
- Int 字面量上限 2147483647（Int32）：`9223372036854775807` 越界报错——概要类计数器初值用 Int32 max 即可。
- labelled 参数函数内部互调也要带标签（`CMS::new(w=w, d=d, seed=seed)`）。

## 第十三轮试跑新增（LogLog 家族，Durand-Flajolet ESA 2003，2026-11-08）

- **⚠ 证明双路径 && 边界最终精化（修正第十二轮）**：`proof_ensure` 的 lambda 形式（`r => ...`）**只在 .mbt 主包契约路径合法**（moonc prove，moon.pkg `options("proof-enabled": true)` + `moon prove .`）；`.mbtp` 证明文件路径 lambda 直接报 "function type wanted Bool"，且 ensure 子句内 `&&` 也非法——.mbtp 只能走 lemma-as-∀（结果升参数 + 布尔式 ensure）。两条 prove 路径语法能力不同，选路径前先定语言。
- **前缀 `!` 是布尔非**：UInt64 按位反不可用 `!x`（报 Bool mismatch）——用全 1 异或 `FULL ^ (mask << off)` 等价实现；`UInt64.leading_zeros` 方法不存在，手写移位循环数前导零。
- **位打包寄存器配方**：FixedArray[UInt64] 字内打包（bits∈{5,6}），跨字寄存器用 room/spill 二段写；`byte_size()` 返回理论打包大小（论文判据口径），实现按字对齐实际更大——注释诚实标注。
- **论文常数缺失时的判据降级路线**：SuperLogLog 截断常数"modified constant α_m"无闭式（排印含糊），无偏性判据不可测——改测论文明说的**另一条性质**（§5(i) 截断降分散度 std 比较）与**机制方向性**（LogLog 过估的种子上截断估计必下移）。论文没给数的东西不硬测，降级到相邻可测命题并登记。
- **UInt32 不实用**：`0U` 字面量/`to_uint32` 转换 API 边界多——位操作统一走 UInt64 域最省事。
- INRIA Flajolet 出版服务器（algo.inria.fr/flajolet/Publications/）存活且直链稳定——老论文优先查作者/机构存档服务器。

## 第十四轮试跑新增（浮点补偿算术 + Double 域压测，Goldberg 1991，2026-11-08）

- **🔴 Double 域 FORMAL 完全不可用（本轮硬压测结论，FORMAL 路由表定论）**：Double 类型上 `==` 在逻辑编码中报 Error 4207 "unsupported primitive operator in logic body"——连恒等式都无法编码。阳性对照确认证明器健康（Int 域假契约 Failed 被抓）。**FORMAL 路由表定论：Double 域一律 RUNTIME，勿写 Double 契约**（此前 FORMAL 域=Int+div/mod+FixedArray 的记录现补全为：Double 明确不支持）。
- **Double 无内建位重解释 API**（探测 to_bits/reinterpret_as_uint64/to_int64_bits 全部不存在；知识库旧记录 `reinterpret_as_uint` 属 Int64↔UInt64 域）——位精确判据改用 IEEE 值相等（==），注意其对 ±0.0/NaN 的标准语义。
- **`@math.abs` 不存在**——Double 用 `.abs()` 方法（第八轮已证）；perl 替换 `@math` 时 `@` 会被当数组插值吞掉，需转义 `\@math`。
- **Dekker 六步 TwoSum 在本环境失效**：b 远小于 ulp(a) 时（a=6.29e91, b=1.04e-111 实测）err 算出 0——b−b' 的舍入吸收了 b。TwoSum 一律用**分支式实现**（|a|≥|b| 调 FastTwoSum，否则换序），偏差登记。教训：文献公式的浮点精确性论证依赖操作数尺度关系，跨尺度随机流测试能击穿背错顺序的实现——这正是"worked example + 极端尺度随机流"判据的价值。
- **Kahan Theorem 8 的可观测强判据**：流 = 2^53 后接 1000 个 1.0：naive 和 = 2^53（小项全被吃），Kahan 和 = 2^53+1000 **值精确**——把论文定理的抽象误差界变成一次性位级断言。
- Goldberg 1991 全文在 docs.oracle.com 有合法 HTML 托管（PDF 链接失效）；HTML→文本用 python3 正则剥标签即可。⚠️ **风控修订（§4.5 事件 #3，2026-11-12）：此法仅限现场阅读以抽取判据/公式/伪代码，禁止把第三方论文全文转存进仓库（paper/content.md 类）——2026-11-11 已实测为版权高风险并全部 git rm + gitignore `paper/`**。引用一律标注出处，代码独立编写。

## 第十五轮试跑新增（CoDel，RFC 8289，系统论文降级路线验证，2026-11-08）

- **🔴 系统工程类论文降级声明验证通过（本轮主题）**：CoDel 的网络/发送器/时钟全部为确定性离散事件 stub（AIMD 发送器 = 行为近似），CoDel 控制律（RFC §5.4-5.6）全量实现——与 RQGM 的 LLM stub 模式完全同构。降级路线配方确认：**"环境类组件 stub 化 + 算法核心全量实现 + 端到端伺服判据"** 适用于系统工程类论文。
- **RFC 是系统工程论文的黄金规范源**：ACM Queue 页面小而难抓，但 RFC 8289（由原作者撰写）含更精确的完整伪代码 + 常数 + 实现注意事项，rfc-editor.org 永远可访问。找系统论文先查有无对应 RFC/draft。
- **first_above_time 语义易错**：CoDel 首次 above TARGET 只 **arm** 计时器（first_above_time=now+INTERVAL，ok_to_drop=false），下一次 dequeue 且 now≥armed 才 ok——单次调用立即 ok 的实现是错的。测试判据要写两步序列。
- **div 单调性 timeout 降级先例**：`100000/c2 <= 100000/c1`（c2>c1）Z3 timeout（div 的非线性单调推理）——正/单调性类 div 判据走 RUNTIME，LIA 保底（≥0 类）可证。
- **moon fmt 会把 Int 显式化为 Int32**：基于字符串匹配的批量补丁要在 fmt 之后跑，或用结构感知工具——字符串 patch 与 fmt 的顺序坑实测两次（第八轮/本轮）。
- 确定性离散事件模拟配方：事件 = (time, kind)，链路服务逐槽推进，AIMD 加性增（每 RTT）/乘性减（观测到 dropping 时减半）——全 Int 域无随机，端到端判据（稳态 min sojourn ≤ TARGET + 利用率 ≥ 0.5）可稳定断言。

## 第十六轮：事实核实 + 全量回归首跑（2026-11-08）

- **项目清单核实（当时快照 2026-11-08；现状见 R26 附录的 17 项目权威清单）**：15 个 moon 项目，**多轮共用容器目录**——xor16-mbt/ 下 6 个独立项目（roaring/eliasfano/hyperloglog/xor16filter/ziplex/lifeguard，各含 moon.mod），顶层 9 个（rqgm/crdt/bwt/chash/cms/codel/fpcomp/loglog/skiplist）。**数项目按 moon.mod 清单数，勿按轮数计**。
- **全量回归首跑（moon 0.1.20261102）：15×check + 15×test + 8×prove 全部 PASS**——此前"升级零破坏"是只在新项目上验证的推断，本轮升级为全量证据。配方在新 moon 版本下成立是**必然性证据**而非运气（所有 API 断言均有 check 背书）。
- **回归脚本假阳性坑**：脚本中 `rm -rf _build/verif` 会触发 safe-delete 守卫（批量删除确认）返回非零，`&&` 链断裂导致 PROVE 假 FAIL——回归脚本**不得用 rm 清 prove 缓存**，缓存命中的 prove 结果同样有效。
- 回归脚本沉淀：`references/regress.sh`，PASS/FAIL 矩阵输出，整体 exit code 反映绿/红。

## 第十七轮：moon 升级 + FORMAL 边界重标定（2026-11-08）

- **升级结果**：官方 cli.moonbitlang.com/install/unix.sh 装到 **moon 0.1.20261104**（download 页 latest 线即 0.1.date 预发布线；官方 v0.10.x 正式线不在这条通道）。升级后 **15 项目全量回归 ALL GREEN**（check/test/prove）——升级零破坏再次全量证据。
- **FORMAL 边界重标定（探针项目 moonprobe/，全部结论不变）**：
  - Double 域 `==` 仍报 Error 4207 unsupported primitive——**Double 禁区未变**
  - .mbtp 路径 lambda 仍 unsupported（function type wanted Bool）、裸布尔 && 仍 parse error——**未变**
  - Int 阳性假契约仍被正确拒绝（timeout 形态）——证明器健康
  - lambda &&（cap_level 同款）仍可证 ✓；div 等式（r == 100000/c2）新版可证 ✓
  - **新增事实：Double 契约错误具有阻断性**——主包一个 Double 探针报 4207 会让同包其余探针全部不跑；排查时务必隔离 Double 探针单独建包
  - **探针复检工具**：`moonprobe/` 项目保留，含全部 6 类边界探针——每次 moon 升级后 `moon prove . + moon prove proofmodel` 即可判边界漂移，无需重写探针
- 官方 v0.10.x 正式线不在这条通道；若需跟踪正式线，另行评估 moonup/版本共存方案。**⚠ 2026-11-12 校准（此条已废）**：`moon --version` 实测 moonc **v0.10.20+65efd5b93**（2026-11-05）、core `version = 0.10.20+65efd5b93`，即 v0.10.x 正是本机编译器/标准库版本线，与构建系统 moon 0.1.date 线属同一工具链的两套组件版本号，无需 moonup。官网 updates 最新为 **20261105 v0.10.19 Release**（moonc v0.10.19）

## 第十八轮：mooncakes 发布链路实测（2026-11-09）

- moon.mod DSL 坑：keywords 数组元素必须带引号（裸逗号列表触发 Lexing error）——模板 `[ ]` 填充按 `"elem"` 格式
- 发布前提：已完成 `moon login`（登录态由工具链管理，勿在文档/代码中引用其文件路径）；`moon publish` 自带 moon check 前置；线上 Moondoc 自动生成 API 文档

## 第十九轮：ChaCha20/Poly1305 + BigInt FORMAL 定论（2026-11-09）

- **BigInt 域 FORMAL 定论**：Error 4207 unsupported expression——与 Double 同判，一律 RUNTIME。**FORMAL 可证域终态 = Int + div/mod + FixedArray**（UInt64 位运算、BigInt、Double 均禁区）
- quickcheck 配方：`moonbitlang/core/quickcheck` 已并入 core（外部 moonbitlang/quickcheck@0.15.1 是旧渠道）；`check((A) -> Bool, seed?, count?)` property 化论文全称判据。**2026-11-12 精确签名核验**（core/quickcheck/pkg.generated.mbti）：`check((A) -> Bool raise?, filter?, observe?, counterexample_context?, count? : UInt32, max_size?, max_shrinks?, discard_ratio? : UInt32, seed? : UInt64, loc~) -> Unit raise`——简写配方仍可用，参数类型以此为准
- API 坑六条：UInt 字面量后缀 `U`（`UL` 是 UInt64）；UInt 无 `rotate_left` 手写 rol；`String.replace` 是 `(String, old~, new~)` 三参非 self 方法；`BigInt.shl/div` 参数是 Int；`mod` 声明必须放 moon.pkg 不许写 .mbt 内；AEAD nonce = fixed-common(counter 派生位) + IV

## 第二十轮：SA-IS 难度压测 + 降级路线定论（2026-11-09）

- **参考实现先行配方**：自研实现连续 ≥3 轮失败（隐式哨兵缺失/种子 cursor 污染/类型比较缺失/契约不一致）→ Python 参考实现先验证判据（banana+随机），再机械翻译 MoonBit 一次通过——自研心智模型不可靠时的正解
- 论文 PDF 不可达降级：结构按论文图表引文 + ≥2 份公开参考实现互证；判据全部改为 SA 定义性判据（perm/有序/朴素 oracle 一致）

## 第二十一轮：合规三查（2026-11-09）

- 判据实现的合规三查：① 思想/表达二分自查（判据引论文、代码原创）② 源许可核查（翻译/移植第三方代码必须有 license——无 license 即默认保留所有权利，翻译属未授权衍生）③ RFC 类规范补版权注记（IETF Trust 条款允许实现性复制）
- 算法思想不受版权保护，全部实现标注论文出处 → 抄袭风险低；ChaCha20/Poly1305 公有领域

## 第二十二/二十三轮：参赛仓库工程化配方（2026-11-09）

- `moon publish` 对库包自动生成 demo main.mbt + pkgtype executable——仓库收集/复制时须配对处理，否则报 "Unexpected main in non-main package"
- 跨机器/目录复制项目必须带 `.mooncakes` 依赖缓存或重装依赖
- GitHub Actions step name 值含"冒号+空格"触发 YAML mapping error；匿名 API 拿不到 jobs/logs（public repo 也要认证），CI 诊断用排除法二分最快

## 第二十四轮：差分矩阵 + CI 定型（2026-11-09）

- 17 项目 × 4 后端差分 **16/17 全一致**；lifeguard native-only 是平台包络（moon.pkg declared supported_targets + 依赖 async native-stub）而非缺陷——交付时诚实标注平台边界

## 第二十五/二十六轮：MMV 审计与深度诊断（2026-11-11）

- 假绿防御实战：rc=0 必须交叉验证 `.proof.json` valid>0（捕获 chacha/fpcomp 两处零契约残留）；双求解器 cross（PATH 移除 z3 → alt-ergo 复跑）达 confirmed 级
- **核心发现：FORMAL 层与实现层"并置而非贯通"**——goals 全为独立引理，fn 级契约挂接数=0，实现正确性机器保证全在 RUNTIME 层。能力提升前，证明是"局部引理证据"而非"函数正确性证书"
- **工具链缺陷级发现：check/prove 的 .mbtp 解析器不一致**——forall 量化的 fn 级契约 prove 路径可证但 check 门报 parse error，双门无法同绿（能力探针：.length() 进逻辑层/数组索引编码/invariant() 循环不变式/forall 数组量化语法均 prove 支持）。moon 1.0 后重试
- **探针残留教训**：诊断探针文件在结论沉淀后必须即删——11-11 实证 fn_probe.mbtp 残留致 cms check/prove 双 FAIL 混入回归矩阵（文件头标注所属轮次是甄别残留的有效约定）
- 2026-11-11 复跑：17 项目全量回归 ALL GREEN（moon 0.1.20261104，17×check + 17×test + 9×prove）
- **当前项目清单权威状态（2026-11-12 核实）**：17 个 moon 项目 = 顶层 11（rqgm/crdt/bwt/chacha/chash/cms/codel/fpcomp/loglog/sais/skiplist）+ xor16-mbt 容器 6（roaring/eliasfano/hyperloglog/xor16filter/ziplex/lifeguard）；17/17 包已发布 mooncakes.io，四后端差分 16/17 一致（lifeguard native-only 属平台包络而非缺陷）。**SKILL.md 与 regress.sh 均以此为基准**；第 16/17 轮的 15 项目记录是当时快照，勿再沿用









## 高频幻觉对照表（Rust/其他语言 → MoonBit 正确写法）

| 幻觉写法（禁止） | MoonBit 正确写法 |
|---|---|
| `impl Trait for Type { }` | trait 用 `trait I { fn f(Self) -> T }`，类型实现直接写方法 `fn I::f(self : Type) -> T`（trait 实现语法） |
| `Option<T>` 模式 `Some(x) => ...` 之外的 `if let` 滥用 | `match opt { Some(v) => ..., None => ... }`，match 是穷尽的 |
| `vec![1,2,3]` / `Vec::new()` | `[1, 2, 3]` 字面量；`Array::new()` 或 `[]`（GC Array） |
| `&str` / `String::from` | `String` 与 `StringView`（切片用 `.blit`/视图操作，非 `&` 借用） |
| `mut` 局部变量处处可变 | `let mut x = ...` 合法但函数参数不可变；可变字段需 `struct` 中显式 `mut` |
| `?` 错误传播运算符 | `try { ... } catch { err => ... }`，错误用 `error` 类型或 `Result[T, E]` |
| 泛型 `fn f<T: Bound>(x: T)` | **泛型参数在 fn 名前**：`fn[T : Bound] f(x : T) -> T`（`fn f[T]` 是 parse error） |
| 高 kinded 类型（`F<A>` 上的泛型） | **不支持**。用 tagless-final：把能力抽象成 trait 参数 `fn run[T : Tensor](t : T)` |
| `loop { }` 无穷循环 | `while true { ... }` 或 `for`；循环不变量证明用 `proof_invariant`（仅 proof 域） |
| `as` 强制转换 | 类型转换用显式函数（`x.to_int()` 等），无任意 `as` |

## 核心语法速记

```moonbit
// 枚举 + 模式匹配
enum Expr { Num(Int); Add(Expr, Expr) }
fn eval(e : Expr) -> Int {
  match e { Num(n) => n; Add(a, b) => eval(a) + eval(b) }
}

// 结构体（可变字段需显式 mut）
struct Node { val : Int; mut next : Option[Node] }

// 泛型 + trait 约束（泛型参数列表在 fn 名之前）
trait Show { show(Self) -> String }
fn[T : Show] show_all(xs : Array[T]) -> String { ... }

// 错误处理
fn parse(s : String) -> Int!ParseErr { ... }  // ! throws 语法
// 调用侧：try { parse(s) } catch { e => ... }

// 测试（moon test）
test "eval: 2+3=5" {
  assert_eq(eval(Add(Num(2), Num(3))), 5)
}
```

## 工具链命令（2026-11-12 依本机 `moon help` 全量校准）

| 命令 | 用途 |
|---|---|
| `moon new <name>` | 新建项目骨架（TOML 风格 `moon.mod` / `moon.pkg`） |
| `moon check` | 类型检查（S5/S6 每文件必跑；v0.10.19 起成功后自动更新 `pkg.generated.mbti`，`--no-mbti` 可关闭） |
| `moon test` | 跑测试（v0.10.19 起测试包默认并行；`-j N` 限并发、`--no-parallelize` 串行） |
| `moon test -p <pkg>` | 只跑指定包（`-p, --package`）；**`-f` 实为 `--filter <FILTER>`（按测试名过滤），不是指定文件**；指定文件用位置参数 `moon test <path>` |
| `moon build` / `moon run` | 构建 / 运行（`runwasm` 已弃用） |
| `moon prove` | 形式化证明（`proof_enabled = true` 包） |
| `moon ide <cmd>` | 语义级 IDE 操作（隐藏命令，help 清单不列；`peek-def` / `find-references`） |
| `moon add <pkg>` | 添加 mooncakes 依赖 |
| `moon explain --diagnostic [<id>]` / `--attribute` | 查官方诊断码 / 属性说明 |
| `moon info` / `moon doc` / `moon fmt` | 生成 `.mbti` 接口 / 文档与符号检索 / 格式化 |
| `moon upgrade` | 升级工具链（`--force` / `--dev`；**实测不支持 `--dry-run`**） |
| `moon testcli` / `moon coverage` | CLI 测试（实验性，替代 cram）/ 覆盖率 |
| `moon login` / `whoami` / `register` / `publish` / `update` | 账号与发布链路（v0.10.19 起 `moon install` 不再用于同步依赖） |

**官方版本体系（2026-11-12 三源核验）**：① 本机 `moon --version`：构建系统 `moon 0.1.20261104 (940aa18 2026-11-04)`、编译器 `moonc v0.10.20+65efd5b93 (2026-11-05)`、`moonrun 0.1.20261104`、feature flags `rr_moon_mod, rr_moon_pkg`；② `~/.moon/lib/core/moon.mod`：`version = 0.10.20+65efd5b93`、license Apache-2.0；③ 官网 updates 最新条目 **20261105 MoonBit v0.10.19 Release**，且 cli `binaries/latest` 与 `cores/core-latest` 的 Last-Modified 均为 2026-11-05 09:5x GMT（11-05 后未更新）→ **本机工具链即官方当前最新通道**。构建系统 0.1.date 线与编译器 v0.10.x 线是同一工具链的两套组件版本号，不是两条发布通道。

## 项目布局约定（对齐 moonbit-agent-guide）

- 清单为 TOML 风格 `moon.mod` / `moon.pkg`（**2026-11-12 官方校准：v0.10.19 起 JSON 清单不再被接受，不是"过时"而是直接报错；`moon fmt` 保留迁移入口**）
- **模块/包名避免连字符**：连字符会破坏黑盒测试的自动 `@别名`（报 "package X is not imported"），显式自导入又触发 Import loop——实测解法是模块名去掉连字符（2026-11-03 roaring-mbt 试跑实证）
- agent 自动化脚本用 `.mbtx` 扩展名（agent 专属约定）
- 文档内嵌代码块用 `.mbt.md`，`moon check` 可检查其中代码
- 测试与实现同包：`xxx.mbt` + `xxx_test.mbt`（黑盒，经 `@pkg` 访问）+ `xxx_wbtest.mbt`（白盒，包内直访）
- **公开定义不能依赖 priv 类型**：pub struct 引用内部枚举/结构体时，字段加 `priv` 前缀：`pub struct R { priv inner : Inner }`
- **查 API 的权威文件**：`~/.moon/lib/core/builtin/pkg.generated.mbti`（全量类型+方法签名，grep 它比猜转换函数名快）
- **位重解释转换**：整型间按位重解释用 `reinterpret_as_*`（实测 `Int32::reinterpret_as_uint -> UInt32`、`Double::reinterpret_as_uint64 -> UInt64`）；`to_uint()` 是**数值转换**（可能截断），位级场景勿混用。**2026-11-12 校准**：core 源码与 .mbti 均无 deprecated 标注且 builtin 内部仍在使用，原"已弃用、出 deprecated 警告"的说法无实证支持，已撤
- **跨包调用**：非根包使用须在 moon.pkg 的 `import {}` 声明；黑盒测试自动导入自身包仅对无连字符包名生效

## 生态可用库（S3 查证起点，非完整清单）

- `moonbitlang/core`：官方标准库（勿手写它已有的）
- `moonbitlang/async`：异步/网络（HTTP/TCP/WebSocket/进程）——**官方 v0.10.19 起新增 `moonbitlang/core/async`（实验性，`moon.pkg` 需 `allow-experimental-packages = true`），官方路线是逐步废弃 `moonbitlang/async`；既有 17 项目仍用旧包且回归全绿，新项目优先评估 core/async**
- `moonbitlang/core/path`、`core/compress`、`core/archive/zip`、`core/json`：v0.10.19 新增/迁移的官方标准库包（Json 与 ToJson 已由内置迁至 core/json，`a.to_json()` 形式移除）
- `moonbitlang/ulex` + `ulex-runtime`：词法分析器生成（moonlex）
- `lyjttio/moongrad`：纯 MoonBit 张量 + autograd（轻量数值场景可考虑）
- mooncakes.io：包注册中心；引第三方库前必须经 moonbit-orientation 查证 API 真实签名

## 环境事实（避免浪费轮次）

- MoonBit 编译快（秒级），`moon check` 循环成本低，可以放开每文件检查
- 静态类型 + 穷尽 match：很多逻辑错误在 check 阶段即暴露——测试没过先看 check 是否真的零警告
- 形式化证明能力边界：元组投影、Double、可变结构体字段、logic fn 内 let 等构造 prove 不支持（moonbit-proof-lab 有 40 个探测包可复现）；遇到即降级，不硬磕

## 官方数据校准（2026-11-12，官网 + 本机工具链 + core 元数据三源核验）

**三源**：① 官网 updates 最新条目 **20261105 MoonBit v0.10.19 Release**（JSON 清单不再接受、core/async 上线、moon test 默认并行、moon check 自动生成 .mbti、1.0 前不发布 1.0+ 包）；② 本机 `moon --version` / `moon help` / core `moon.mod`（`moon 0.1.20261104`、`moonc` 与 `core` 均 `v0.10.20+65efd5b93`、flags `rr_moon_mod,rr_moon_pkg`）；③ cli `binaries/latest` 与 `cores/core-latest` 的 Last-Modified 均为 **2026-11-05 09:5x GMT**（11-05 后未更新）→ **本机即官方当前最新通道**。

| 官方数据项 | 核验结论 |
|---|---|
| 版本线 | moon 0.1.date（构建系统）与 moonc/core v0.10.x（编译器/标准库）是**同一工具链的两套组件版本号**；原"v0.10.x 正式线不在这条通道、需 moonup"断言已废 |
| 清单格式 | TOML `moon.mod`/`moon.pkg`；**v0.10.19 起 JSON 清单直接拒绝**；pipeline 原写 `moon.mod.json` 已废 |
| 权威文档 | `~/.moon/lib/core/AGENTS.md` 有效；`~/.moon/AGENTS.md` 为失效符号链接（指向 moon-pilot 内部文件） |
| 命令集合 | `moon prove` / `moon ide`（peek-def、find-references）/ `moon explain --diagnostic` 实测存在；新增 `upgrade`、`info`、`testcli`、`coverage`、`doc`、`whoami` 等；**`moon upgrade --dry-run` 不支持** |
| 测试参数 | `-p` 指定包；**`-f` = `--filter`（测试名过滤），不是文件**；指定文件用位置参数；v0.10.19 起测试包默认并行（`-j N` / `--no-parallelize`） |
| 证明配置 | 项目实测统一 `proof_enabled = true`（8 处）；`options("proof-enabled": true)` 已废 |
| API | `String::replace(String, old~ : StringView, new~ : StringView)` ✓（另有 `replace_all`）；UInt 无 `rotate_left` ✓；`reinterpret_as_uint` / `reinterpret_as_uint64` ✓；`@math.ln` / `@math.exp` ✓（Double→Double）；`to_uint` 无 deprecated 标注，是数值转换而非位重解释 |
| quickcheck | 确在 core 内（`core/quickcheck`）；精确签名见 R19 章节；v0.10.9 起提供 `report`、`Generator::sample`、`shrink` 子包 |
| 异步生态 | 官方路线：`moonbitlang/core/async`（实验性）→ 逐步废弃 `moonbitlang/async`；既有 17 项目用旧包，回归全绿 |
| 形式化边界 | Error 4207 / 可证域 Int+div/mod+FixedArray / Double·BigInt·UInt64 位运算禁区：本机 9×prove 全绿维持（工具链版本未变，结论不漂移） |
| 官网页面滞后 | 官网 download 页展示的 `moon help` 输出为旧版（无 prove/explain/upgrade）——**命令事实以本机 `moon help` 为准** |

**待观察**：官网明示"MoonBit 1.0 前暂不支持发布 1.0+ 版本包"；1.0 发布后须重跑 17 项目全量回归 + moonprobe 边界重标定（ROADMAP 监控项）。
