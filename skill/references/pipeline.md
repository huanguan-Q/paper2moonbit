<!-- last_updated: 2026-11-03 -->
<!-- ref: class=P1; threshold=常驻; load_when=执行任一阶段前 -->

# 流水线详细操作（S0–S7）

## S0 环境自检

1. 运行 `moon version`。成功 → 直接进 S1。
2. 失败（命令不存在/版本过旧/编译报环境错误）→ 加载 **moonbit-cli-manager** 技能处理，修复后继续。
3. 预算：本阶段总耗时不超过 2 分钟。工具链问题当场修不好就报告用户并停止，不要带病进入生成阶段。

## S1 论文解析

输入：论文 PDF/URL/文件路径。

产出「算法抽取清单」，逐项列出：
- **核心算法**：伪代码编号（Algorithm X）、每个算法的输入/输出/不变量
- **数学公式**：需要转成代码的公式（标注论文公式编号，便于回溯）
- **数据流**：输入数据 → 中间表示 → 输出的变换路径
- **超参与配置**：默认参数、可调参数（后续进 config）
- **测试判据**：论文中的已知结果（示例输入/输出、复杂度声明、边界行为），作为 S4/S6 测试依据

范围确认：算法 ≥2 个时，向用户确认实现范围（全部 vs 核心），把未实现项写入最终交付报告。

## S2 蓝图蒸馏

产出蓝图文档（存为项目内 `BLUEPRINT.md`），必须包含四节：

```markdown
# 蓝图
## 1. 架构
包/模块划分，一句话说明每个模块职责。
## 2. 文件清单与依赖序
| 顺序 | 文件 | 职责 | 依赖 |
|---|---|---|---|
| 1 | src/types.mbt | 核心类型定义 | 无 |
| 2 | src/core.mbt | 算法主体 | types |
依赖序 = 上表顺序（拓扑序，被依赖者在前）。
## 3. 接口签名
每个对外函数的 MoonBit 签名（先写成签名，S4/S5 填实现）。
## 4. Config
默认超参表（moon.mod.json + 常量模块或配置结构体）。
```

完成后**向用户展示**文件清单和依赖序，得到确认再进 S3。此蓝图是后续所有阶段的合同：S5 按依赖序生成，S6 修复循环超限时回滚到这里。

## S3 语境注入

目的：补齐 MoonBit 语料稀缺短板，生成前先查证、后动手。

1. **先读本机权威文档**：`~/.moon/lib/core/AGENTS.md`（标准库布局、重构与 moon info/fmt 约定；2026-11-12 核实：`~/.moon/AGENTS.md` 是指向 moon-pilot 内部文件的失效符号链接，勿引用），以及 `moon new` 生成的模板注释（新工具链的 moon.mod/moon.pkg 格式、测试文件约定都在其中）。
2. 加载 **moonbit-orientation**，逐项查证：
   - 蓝图接口签名用到的标准库/core API 是否存在、真实签名是什么
   - 蓝图中假设的数据结构 MoonBit 是否原生提供（`Map`/`Option`/`Result`/`FixedArray` 等）
   - 记录「论文假设 vs MoonBit 实际」的差异清单，必要时修订 S2 蓝图
2. 加载 **moonbit-agent-guide**，确定项目骨架（**TOML 风格 `moon.mod` / `moon.pkg`**——官方 v0.10.19 起 JSON 清单不再被接受，勿再写 `moon.mod.json`；源文件与测试目录布局），执行 `moon new` 或手工建骨架。

## S4 规格先行

加载 **moonbit-spec-test-development**，为蓝图中的每个对外函数建立：
- `spec.mbt`：前置条件、后置条件、函数签名（`declare` 形式）
- 测试文件骨架：测试签名对齐 S1 的「测试判据」（论文已知结果 → 测试用例）

规格是 S5 实现的正确性标尺。此阶段只写规格和测试签名，不写实现。

## S5 代码生成

**路由决策（进入本阶段时做一次，七条配方）**。判断依据是「论文贡献是什么」，不是「论文领域是什么」：

| 判断问题 | 命中 → 路由 | 配方要点 |
|---|---|---|
| 贡献 = 词法文法/语法本身，要把文法变成 lexer？ | **moonbit-lexgen**（.mbtx 规格生成 DFA） | 只此情形才用生成器 |
| 贡献 = 解析引擎算法（导数法/Packrat/Earley）？ | **纯手写解释器** | 禁止走 lexgen——生成会绕开论文贡献（ZipLex 实证） |
| 纯函数核心、性质可写成算术/逻辑命题？ | **instinct-driven-moonbit CAPT（FORMAL 域）** | probe 先行；UInt64 位运算不可证 → 数学整数建模或降级 RUNTIME；必须保留论文判据测试（证明≠语义） |
| 网络协议/共识/gossip/故障检测？ | **moonbit-async 确定性仿真** | 不碰真实 socket；状态机与 driver 分文件，状态机可脱离 async 单测 |
| 密码学原语（流密码/AEAD/MAC）？ | **主线 + 规格先行；验证只走 RUNTIME** | BigInt/Double 域 FORMAL 不可证（Error 4207）；RFC 全向量判定 + core 内置 quickcheck property 化全称判据；AEAD nonce = fixed-common + IV（R19 实证） |
| 论文 PDF 不可达或自研连续 ≥3 轮失败？ | **降级：参考实现先验证再机械翻译** | ≥2 份公开参考实现互证 → 脚本语言先验判据 → 机械翻译 MoonBit；先核源许可（无 license = 未授权衍生），判据改定义性判据（R20/R21 实证） |
| 以上皆否（数据结构/压缩/概率结构等）？ | **主线 + 规格先行** | S4 论文判据→测试先行，instinct-driven 或直接实现向测试收敛 |

各路由详细配方与实测坑位见下方分类条目。

- **密码学原语路由（2026-11-09 ChaCha20/Poly1305 实证）**：S1 直接把 RFC 标准测试向量抽成判据（T-QR/T-BLOCK/T-POLY/AEAD 等），S4 写全向量测试；实现按 RFC 伪代码逐块机械翻译，每块立即 moon check。高频 API 坑：UInt 字面量后缀 `U`（`UL` 是 UInt64）、UInt 无 `rotate_left` 需手写 rol、`String.replace(String, old~, new~)` 三参非 self 方法、`BigInt.shl/div` 参数是 Int、`mod` 声明必须放 moon.pkg。BigInt 域 FORMAL 报 4207 → 一律 RUNTIME；全称性质用 core 内置 quickcheck property 化。
- **降级路线（2026-11-09 SA-IS 实证 + R21 合规）**：论文 PDF 不可达时，结构依论文图表引文 + ≥2 份公开参考实现互证；判据改用定义性判据（perm/有序/朴素 oracle 一致）。自研连续 ≥3 轮失败即切换：先在脚本语言跑通参考实现判据，再机械翻译 MoonBit。**翻译前必须核源许可**——无 license 的公开代码默认保留所有权利，翻译即未授权衍生；须改为独立实现并留 Provenance 声明（合规三查：思想/表达二分、源许可、RFC 版权注记）。

按 S2 依赖序逐文件生成，第 i 个文件的生成输入 = 论文对应章节 + 蓝图该文件职责 + 其依赖的已生成文件的真实签名 + S4 对应规格。**每个文件写完立即执行 `moon check`**，失败当场修（见 S6 修复规则），绿了才生成下一个文件。

形式化路线（可选，需满足：纯函数域 + 用户要求或算法关键）：按 instinct-driven-moonbit 定义 Contract 前后置条件，`moon prove` 验证。降级域（while 后置条件、GC Array、Map、@math.*、Double/BigInt/UInt64 位运算——R19 定论：FORMAL 可证集仅 Int + div/mod + FixedArray）不硬上证明，退回 `proof_assert` + moon test + PBT。**R26 工具链缺陷**：fn 级 forall 契约 prove 可证但 check 门报 parse error（.mbtp 解析器不一致），双门无法同绿；诊断探针用完即删，勿留在交付包（cms 回归红灯实证）。

## S6 验证闭环

循环：`moon check` → 修复 → `moon test` → 修复。

- **修复预算**：单文件不超过 5 轮修复。超限 = 蓝图/规格有误，回 S2 修订并告知用户，禁止第 6 轮硬修。
- **排错升级**：连续 2 轮同一种编译错误修不掉 → 加载 **moonbit-orientation** 做 API/诊断查证。
- **形式化排错**（走了证明路线时）：`moon prove` 报 unsupported → 先用 **moonbit-proof-lab** 的 lint 预检语言边界；归因不清 → **moonmeta-verifier** 解读 prove 输出与失败归因。
- **`moon prove` 可选分支（实测边界，2026-11-03）**：环境开箱即用（内置 Why3 + z3/alt-ergo）。但 UInt64 全部位运算未下发证明层——位级不变量无法直接证明，须走**数学整数建模**（.mbtp 里 div/mod 恒等式）。证明放独立纯证明包（proof_enabled 包内含 Array 的 struct 会下发失败 `unbound type symbol 'array'`）。仅当论文判据可表述为纯算术/逻辑性质时启用本分支，位操作密集的算法直接跳过并记入偏差。
- **测试挂死排查**：`moon test` 长时间无输出 → 先查含变量移位的循环（wasm 移位按 64 取模，`q >> 64 == q`，上界不守卫即死循环），再查别的。
- **领域路由细化（2026-11-03 ZipLex 试跑实证）**：解析器类论文先问"论文贡献是什么"——①贡献 = **词法文法/语法，需要把文法变成 lexer** → 走 **moonbit-lexgen**（.mbtx 规格生成 DFA）；②贡献 = **lexer/解析引擎算法本身**（如 ZipLex 导数法、Packrat、Earley）→ **纯手写解释器**，用 moonlex 生成会绕开论文贡献。两类都可能需要，先读 S1 抽取的算法清单再定。
- **async/网络协议路由（2026-11-03 Lifeguard 试跑实证配方）**：协议类论文（成员协议/共识/限流）**不要碰真实 socket**——论文贡献在协议逻辑不在传输。先加载 **moonbit-async**，但只用 `with_task_group + @async.sleep + Queue` 做**确定性仿真**（虚拟总线 = relay 任务 + 固定投递延迟，死节点 = 无人消费的 inbox）。配方：`moon add moonbitlang/async` → moon.mod `preferred_target="native"` → moon.pkg `supported_targets="+native"` → 纯状态机（swim.mbt）与 driver（async）分文件、状态机可脱离 async 单测。集成断言写论文级判据（故障检测收敛 + 零误报），预算函数给足墙钟（sleep 粒度使墙钟 > 仿真时钟）。
- **instinct-driven-moonbit 主线路由（2026-11-03 HyperLogLog 试跑实证）**：论文含**纯函数算法核心**（位操作语义可改写为 div/mod、性质可写成"对所有输入成立"）→ 加载 instinct-driven-moonbit 走 CAPT：①C1 按"三条件速判"分层——可证函数（Int 算术+for+FixedArray）写 `where{proof_require/proof_ensure}` + 循环不变量，浮点/`@math.*`/UInt64 位运算部分降级 RUNTIME+论文判据测试；②**probe 先行**（单函数先证通）；③W6 三件套（rc==0+Summary+goals>0）采信 prove 结果；④**必须保留论文判据级运行时测试**——Z3 验证的是 contract 一致性而非论文语义，两者正交（双重 rho bug 实证：Z3 全证、运行时错 5 倍、只有论文判据测试抓到）；⑤参数命名避开 Why3 保留字（`old` 等）。
- **通过标准**：见 SKILL.md「质量门（Quality Gate，完成定义）」四条，缺一不可。

## S7 收尾

1. 加载 **moonbit-refactoring**：检查生成代码的惯用法（API 收缩、模式匹配、循环不变量），做无回归重构（每步重构后 `moon test` 必须仍全绿）。
2. 加载 **moonbit-extract-spec-test**：对实现补齐遗漏的测试套件（valid/invalid 用例）。
3. 按 SKILL.md 的「交付报告模板」输出报告。

## 常见失败机制速查

| 症状 | 根因 | 处置 |
|---|---|---|
| moon check 报不存在的语法（`impl`/`trait object` 等 Rust 风味） | Rust 幻觉 | 对照 references/moonbit-context.md 语法卡片重写 |
| 跨文件签名对不上 | 跳过了依赖序或用了蓝图旧签名 | 回到 S2 依赖序重排，用真实已生成签名重新生成 |
| 测试全过但结果与论文不符 | 测试判据抄错或简化了算法 | 回 S1 核对公式与判据，向用户报告偏差 |
| moon prove 反复 unsupported | 命中求解器语言边界 | moonbit-proof-lab 预检，降级为运行时断言 + 测试 |
| prove 全证但运行结果与论文差一个数量级 | contract 与论文语义脱节（如双重 rho bug） | **证明≠语义**：核对 contract 是否忠实转写论文公式，修语义而非修 contract |
| `moon test` 无输出挂死 | 变量移位循环 wasm 按 64 取模（`q >> 64 == q`） | 加上界守卫（`l < 63 &&`），或改 while 递增 |
| 黑盒测试报 package not imported / Import loop | 模块名含连字符 | 模块名去连字符（roaring 实证） |
| 单测全过、集成断言全挂 | struct literal 形参名与字段名错位（如 envelope 寻址） | 逐字段核对 struct literal 传参 |
