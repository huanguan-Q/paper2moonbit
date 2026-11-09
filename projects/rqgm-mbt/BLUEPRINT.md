# BLUEPRINT — rqgm-mbt（RQGM harness 核心，降级实现）

## 架构：单包 `src/`（项目根级 .mbt 文件，同 crdt-mbt 模式）+ 独立证明包 `proofmodel/`

模块名：`huanguan-Q/rqgm`（无连字符）

## 文件清单与依赖序（生成顺序）

| # | 文件 | 职责 | 依赖 |
|---|------|------|------|
| 1 | `betainc.mbt` | Lanczos log-gamma、正则化不完全 Beta I_x(a,b)（连分式 betacf，对称性 x>(a+1)/(a+b+2) 时换侧）、逆函数 BBε（二分求 I_x=ε）、Beta 采样（Erlang 分解 + 种子 LCG） | — |
| 2 | `lcg.mbt` | UInt64 LCG 种子化随机数（复用 HLL 配方） | — |
| 3 | `archive.mbt` | Node(id,parent)、Record{node,dep:Set[Int],kappa:Int,outcome}、Archive{nodes,records,children}；CMP 合并统计（clade 求和）；派生统计重算 | — |
| 4 | `schedule.mbt` | C_B(ρ,h) 检查点生成、next_checkpoint(N)、重处理计数器 | — |
| 5 | `erasure.mbt` | Erase_m 过滤（Def. F.2 语义）、擦除后重算统计、顺序无关组合 | archive |
| 6 | `harness.mbt` | Algorithm 1 主循环：ExpandGate（UCB-Air）、SampleCladeByCMP（Thompson）、LeastMeasuredCell、替换规则（anchor BBε、平局 incumbent）、端点选择；LLM stub 接口（trait 化的 Eval/Edit 函数注入） | 1-5 |

## 测试文件

- `rqgm_test.mbt`：T-CMP / T-GATE / T-ERASE / T-SCHED / T-REPLACE / T-HARNESS（11+ 测试）
- `betainc_test.mbt`：T-BB-NUM / T-BB-CONSERV（参考值来自 scipy 生成后硬编码，1e-9 容差）

## FORMAL（proofmodel/verify.mbtp）

- `cmp_mono(a,b,m)`：m ≥ 1 → (a+m)·b ≤ (b+m)·a（CMP 加成功不降，交叉相乘 LIA）
- `erase_len`：过滤长度 ≤ 原长度（如证明层支持数组长度则证，否则降 RUNTIME）
- 预登记：2^q 几何和非线性，若 unsupported 即降级 RUNTIME 断言（知识库已知边界）

## 判据映射（论文 → 测试）

| 论文命题 | 测试 |
|---|---|
| §3.1 CMP 定义 | T-CMP 三例（根/叶/单链） |
| §3.3 \|T_t\|=O(N^α) | T-GATE 不变量 |
| Prop.4 保守下界 | T-BB-CONSERV |
| Def.F.2 擦除语义 | T-ERASE-SPEC |
| Remark 1 顺序无关 | T-ERASE-COMMUTE |
| Prop.6 线性界 ρ/(ρ−1) | T-SCHED-BOUND |
| Remark 7 均匀检查点 Θ(B²/h) | T-SCHED-UNIFORM-QUADRATIC |
| Remark 3 平局 incumbent / never-worse | T-REPLACE-TIE, T-REPLACE-NOTWORSE |
| Alg.1 端点选择 | T-HARNESS-ENDPOINT |

## 明确不实现

LLM 调用、真实 EditWorkspace、论文 §5 实验复现、op-based 传输、adversarial pool 采样策略（Rem.2 的记录打标已覆盖，策略本身属 LLM 层）。
