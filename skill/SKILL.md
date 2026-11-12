---
name: paper2moonbit
description: "论文转 MoonBit 代码编排技能（Paper2MoonBit）。输入一篇研究论文（PDF/URL/文件路径），输出可编译、可测试、带规格的 MoonBit 实现。分七阶段流水线编排本机 MoonBit 技能族：moonbit-cli-manager（环境自检）、moonbit-orientation（API 查证）、moonbit-agent-guide（项目规范）、moonbit-spec-test-development（规格先行）、instinct-driven-moonbit（验证式代码生成）、moonbit-proof / moonbit-proof-lab / moonmeta-verifier（形式化验证）、moonbit-lexgen（解析器类论文）、moonbit-async（网络类论文）、moonbit-refactoring（惯用法收尾）、moonbit-extract-spec-test（补测试）。触发词：论文转代码、paper2moonbit、paper to moonbit、论文转 MoonBit、复现论文、论文复现、用 MoonBit 实现论文算法、把这篇论文实现成项目、arxiv 转代码、论文代码化；数据结构/概率算法论文（Bloom filter、quotient filter、Roaring Bitmap、Elias-Fano、HyperLogLog、MinHash、压缩索引、后缀数组/SA-IS）；密码学/流密码/AEAD 论文（ChaCha20、Poly1305）；解析器/词法/DSL/正则引擎论文；网络协议/共识/gossip/故障检测论文（SWIM、CRDT）；要求形式化验证或 moon prove / Z3 contract 的实现。NOT for: 直接回答论文内容问题（无生成意图）、Python/Java 等其他语言的论文实现、通用 MoonBit 编程问答（→ moonbit-orientation）。"
version: "0.3.3"
metadata:
  author: "local"
  changelog: "v0.3.3 (2026-11-12) 依 MoonBit 官网 20261105 v0.10.19 公告 + 本机 moon --version / core moon.mod / cli latest 时间戳逐条校准官方数据：纠正 v0.10.x 版本线断言、JSON 清单已拒绝、AGENTS.md 权威路径、moon test -f 语义、proof_enabled 写法、to_uint 弃用说法、async 迁移方向、quickcheck 精确签名，并补官方组件版本与命令清单；v0.3.2 (2026-11-12) 依公开风控 SOP 审计修订：知识库 R14 论文全文抓取配方加版权否定标注（事件 #3 同源）、pipeline 去「全文」歧义、两版同步；v0.3.1 (2026-11-12) 全面核查收口：regress.sh 默认工作区改用 pwd、审计 hash 重标定、知识库补 17 项目权威清单并标注历史快照、pipeline.md S5 五条→七条路由配方同步、发布配方改用 moon login 表述、仓库副本同步；v0.3.0 (2026-11-11) 跟进 R18-R26：领域清单+2（ChaCha20/Poly1305 密码学、SA-IS 后缀数组）、回归套件 15→17、BigInt 域 FORMAL 定论入路由（FORMAL 可证域终态=Int+div/mod+FixedArray）、quickcheck 配方、合规三查、MMV 假绿防御配方、工具链缺陷记录（check/prove 解析器不一致）；v0.2.0 (2026-11-03) 六轮试跑收束：新增五条领域路由决策表（数据结构规格先行/位结构数学建模/词法文法 vs 引擎手写/async 确定性仿真/CAPT-FORMAL）；核心原则写入「证明≠语义」；触发词扩展至算法名、协议类与验证类；AVOID 补prove盲区与变量移位死循环"
---

# Paper2MoonBit — 论文转 MoonBit 代码编排

## 定位与边界

本技能是**编排器**：把一篇论文的算法逻辑转化为 MoonBit 代码仓库。方法骨架来自 PaperCoder（Plan→Analyze→Code）与 DeepCode（信道优化四操作），目标语言为 MoonBit，并利用 MoonBit 形式化验证生态做出差异化。

**适用**：算法/数据结构/解析器/编译器/协议类论文（纯逻辑，无重型依赖）。已实测通过的论文类型（**2026-11-12 核验的官方最新通道**：构建系统 moon 0.1.20261104 / 编译器 moonc 与 core v0.10.20+65efd5b93，官网 updates 最新 20261105 v0.10.19；此组合下全量回归验证；**领域清单的单一权威定义在 references/moonbit-context.md 按轮次章节**，此处为摘要）：位图数据结构（Roaring）、压缩编码（Elias-Fano）、概率估计（HyperLogLog）、过滤器（Xor16）、词法引擎（ZipLex）、成员协议（Lifeguard/SWIM）、分布式协作数据结构（CRDT）、搜索调度 harness + 数值统计核心（RQGM：Thompson 采样/逆不完全 Beta，LLM 组件 stub 化）、文本压缩管线（BWT：字符串变换/自适应编码）、概率性数据结构/有序字典（Skip List：几何分布层数 + oracle 序列测试）、分布式系统算法（一致性哈希：ranged hash family + 单调性/平衡/平滑性判据）、概要数据结构（Count-Min Sketch：单侧误差/行和守恒/ε·N 窗口判据）、基数估计家族对比（LogLog/SuperLogLog：位打包寄存器 + 多种子误差序与分散度判据）、浮点补偿算术（Goldberg 1991：FastTwoSum/Kahan，Double 域 FORMAL 不可用定论）、系统工程类（CoDel/RFC 8289：环境 stub 化降级路线验证）、密码学原语（ChaCha20/Poly1305 RFC 8439：全向量判定 + AEAD nonce 构造 + BigInt FORMAL 定论）、字符串索引（SA-IS 线性后缀数组 DCC 2009：论文 PDF 不可达降级 + 参考实现先验证再机械翻译路线）。

**回归套件**：`scripts/regress.sh`——17 个实例项目（moon check/test/prove 矩阵）的一键全量回归。工具链升级后必跑：`sh regress.sh <workspace>`。项目清单注意：多轮共用容器目录（xor16-mbt/ 下 6 个独立 moon 项目），顶层另有 11 个——**以目录清单为准，勿按轮数计**。首跑（moon 0.1.20261102）与升级复跑（moon 0.1.20261104，含差分矩阵 17 项目 × 4 后端）均验证通过；脚本内不得用 `rm -rf` 清证明缓存（会触发 safe-delete 拦截造成假阳性 FAIL）。
**不适用**：需要 PyTorch/numpy 重型训练生态的 ML 复现类论文——MoonBit 科学计算生态尚不成熟。遇到此类论文，明确告知用户局限，建议降级为「只实现核心算法模块」。

## 核心原则

1. **蓝图是合同**：S2 蓝图（文件清单+依赖序+签名）一经用户确认即为后续所有阶段的基准；S5 按依赖序生成，修复超限回滚到蓝图而非硬修。
2. **编译器反馈优先**：MoonBit 编译秒级、报错精确，每写一个文件立即 `moon check`，让编译器替代猜测。
3. **证明 ≠ 语义**（最重要方法论结论，六轮试跑实证）：`moon prove`/Z3 验证的是**实现与 contract 的一致性**，不验证 **contract 与论文语义的一致性**。双重 rho bug 实证：contract 自洽、Z3 全部证毕，运行期估计仍系统性偏低 5 倍，只有论文判据测试抓到。因此**任何走了形式化路线的实现，必须同时保留论文判据级运行时测试**（论文中的已知结果、误差界、收敛行为），两者正交、缺一不可。
4. **论文判据先行**：S1 解析时就把论文的已知输入输出、误差界、边界行为抽成测试判据，S4 变成测试，S6 用它判定"实现了论文"而不只是"代码能跑"。

## 核心风险（决定成败）

1. **Rust 语法幻觉**：MoonBit 公开语料少，模型零样本 pass@1 接近 0%，大量失败是语法错误。对策：生成前先读 `references/moonbit-context.md` 语法卡片与幻觉对照表。
2. **依赖序错乱**：PaperCoder 消融证明「逻辑设计（文件依赖与执行顺序）」是成败转折点。对策：蓝图阶段产出显式依赖序，按序生成。
3. **伪完成**：代码能编译 ≠ 实现了论文。对策：原则 3 与 4——论文判据测试 + （可选）形式化证明双轨。

## AVOID — 禁止事项（违反任一条会使该阶段产出失效）

- **禁止**跳过 `moon check` 直接把生成的代码交付给用户。
- **禁止**一次性加载全部依赖技能——每阶段只加载当前阶段对应的**一个**技能（多技能堆叠会互相干扰，实测性能下降）。
- **禁止**把论文伪代码直接逐行翻译成 MoonBit 而不经过蓝图阶段——直接翻译是失败的主要来源。
- **禁止**在 spec 与实现冲突时静默修改 spec 迁就实现；冲突必须回到蓝图阶段重新决策并向用户报告。
- **禁止**把「moon prove 全部证毕」当作实现正确的充分证据（见核心原则 3，prove 盲区实证）。
- **禁止**写含变量移位的循环不上界守卫——wasm 移位按 64 取模（`q >> 64 == q`），会造出 `moon test` 无输出挂死的死循环。
- **禁止**使用含连字符的模块名——会破坏黑盒测试自动别名并触发 Import loop（roaring 试跑实证）。

## 领域路由表（五条配方，S5 进入前定一次）

按「论文贡献是什么」判断，不是按「论文领域」判断：

| 论文贡献类型 | 路由 | 配方要点 |
|---|---|---|
| 数据结构/压缩/概率结构（Roaring、Elias-Fano、过滤器类） | 主线 + 规格先行（moonbit-spec-test-development） | S4 先把论文判据写成测试，实现向测试收敛 |
| 纯函数核心、性质可写成算术/逻辑命题（HyperLogLog 类） | instinct-driven-moonbit CAPT（FORMAL 域） | probe 单函数先证通；UInt64 位运算不可证 → 数学整数建模（div/mod 恒等式）或降级 RUNTIME |
| 贡献 = 词法文法/语法本身，需把文法变成 lexer | moonbit-lexgen（.mbtx 规格生成 DFA） | 仅当贡献在文法时使用 |
| 贡献 = 解析引擎算法（Brzozowski 导数、Packrat、Earley） | 纯手写解释器 | 用 moonlex 生成会绕开论文贡献，禁止走 lexgen |
| 网络协议/共识/gossip/故障检测 | moonbit-async 确定性仿真 | 不碰真实 socket：虚拟总线 = relay 任务 + 固定延迟，死节点 = 无人消费的 inbox |
| 密码学原语（流密码/AEAD/MAC，ChaCha20、Poly1305 类） | 主线 + 规格先行；验证走 RUNTIME | BigInt 域 FORMAL 不可证（Error 4207）→ 一律 RUNTIME 全向量判定；核心域 FORMAL 可证集 = Int + div/mod + FixedArray；全称判据用 core 内置 quickcheck property 化 |
| 论文 PDF 不可达 / 自研实现连续失败（≥3 轮） | 降级：参考实现先验证再机械翻译 | 公开参考实现（≥2 份互证）先在脚本语言验证判据，再机械翻译 MoonBit 一次过；注意源代码许可核查（无 license = 默认保留所有权利，翻译即未授权衍生） |

详细配方与每条路由的实测坑位见 `references/pipeline.md` S5 节。

## 七阶段流水线

每阶段产出物是下一阶段的输入。详细操作步骤见 `references/pipeline.md`；MoonBit 语言知识见 `references/moonbit-context.md`（进入第 4 阶段前必读）。

| 阶段 | 产出物 | 编排的技能（一次一个） |
|---|---|---|
| S0 环境自检 | moon 工具链可用确认 | moonbit-cli-manager |
| S1 论文解析 | 算法抽取清单（伪代码/公式/数据流/超参/**测试判据**） | 本技能内置（无依赖） |
| S2 蓝图蒸馏 | 架构图 + 文件清单 + 依赖序 + config | 本技能内置（模板见 references/pipeline.md） |
| S3 语境注入 | API 查证结果 + 项目骨架决策 | moonbit-orientation → moonbit-agent-guide |
| S4 规格先行 | spec.mbt（前置/后置条件 + 测试签名） | moonbit-spec-test-development |
| S5 代码生成 | 按依赖序生成的 .mbt 文件 | 按领域路由表选**一个**：instinct-driven-moonbit / moonbit-lexgen / moonbit-async |
| S6 验证闭环 | moon check/test 全绿 + 可选形式化证明 | moon check/test 内置；深入排错 → moonbit-orientation；形式化 → moonbit-proof（配 moonbit-proof-lab 预检、moonmeta-verifier 归因） |
| S7 收尾 | 惯用法优化 + 补全测试套件 + 交付报告 | moonbit-refactoring → moonbit-extract-spec-test |

## 流程控制要点

- **S0 快速通过**：`moon version` 正常即跳过，不要在环境上花超过 2 分钟。失败才调 moonbit-cli-manager。
- **S1 先问范围**：论文超过一个核心算法时，先向用户确认要实现的范围（整篇 vs 核心算法），再进入 S2。
- **S2 蓝图是合同**：蓝图完成后向用户展示文件清单和依赖序，确认后再生成。
- **S3 骨架即查证**：项目骨架用 `moon new` 生成而非手写（清单格式 TOML 风格 moon.mod/moon.pkg），模块名去掉连字符。
- **S5 每文件一检查**：生成第 i 个文件时，输入必须包含 S2 蓝图中它依赖的、已生成文件的真实签名（dependency-aware 生成）；写完立即 `moon check`。
- **S6 修复预算**：单文件 `moon check` 修复循环不超过 5 轮；超限说明蓝图有误，回 S2 而不是继续硬修。测试挂死先查变量移位循环。
- **形式化验证是加分项不是必选项**：默认只跑 moon check/test。用户明确要求或算法核心是纯函数域时才走 instinct-driven-moonbit 的 Contract+Z3 路线（while 后置条件、GC Array、Map、Double 等属于降级域，见其文档），且必须保留论文判据测试（核心原则 3）。

## 质量门（Quality Gate，完成定义）

任务只有同时满足以下四条才算完成，缺一即回 S6 修复循环：

1. `moon check` 零错误零警告
2. `moon test` 全绿
3. S4 规格对应的测试覆盖所有对外函数
4. 论文判据测试通过——论文已知结果/误差界在运行期复现；走了 prove 路线的另需 W6 三件套（rc==0 + Summary 行 + goals>0），并在交付报告声明「证明 ≠ 论文语义」

## 交付报告模板

任务结束时必须向用户报告：
1. 实现范围（实现了论文哪部分，明确列出未实现部分）
2. 验证状态（moon check/test 结果；有形式化证明则列证明覆盖的函数与 goals 数，并声明证明≠论文语义）
3. 与论文的偏差点（任何简化、近似、替代实现）
4. 复现步骤（moon build / moon test 命令）

## 词汇表（单一事实源）

- **蓝图**：S2 产出的仓库级设计文档，含文件清单、依赖序、config。本技能内不再使用「规划/施工图/roadmap」等同义词。
- **依赖序**：拓扑排序后的文件生成顺序。
- **验证闭环**：`moon check` → 修复 → `moon test` → 修复 的迭代循环。
- **路由**：S5 进入前对「论文贡献类型」的一次性判断，决定加载哪个生成技能。本技能内不再使用「分流/分支策略」等同义词。
- **论文判据**：S1 从论文中抽取的客观验证标准（已知输入输出、误差界、收敛行为），是运行时测试的最终依据。
