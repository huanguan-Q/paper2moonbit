# BLUEPRINT — loglog-mbt（LogLog 家族三估计器对比）

模块名：`huanguan-Q/loglog`（无连字符）。单根包 + 独立证明包 `proofmodel/`。

## 文件清单与依赖序

| # | 文件 | 职责 | 依赖 |
|---|------|------|------|
| 1 | `lcg.mbt` | UInt64 LCG（流与测试随机源） | — |
| 2 | `mix.mbt` | mix64 哈希；rho(y)=首个 1 位位置（前导零+1）；桶选择（高 k 位） | — |
| 3 | `regs.mbt` | PackedRegs：FixedArray 32-bit 字内位打包（bits∈{5,6}）、put/get、register_bytes；`cap_reg` Z3 契约 | 2 |
| 4 | `loglog.mbt` | LogLog（5-bit packed，α_∞）+ estimate + merge（逐寄存器 max）+ superloglog 估计（计数排序截断 θ₀=0.7） | 3 |
| 5 | `hll.mbt` | HLL（6-bit packed，α_m 分段 + 小基数线性计数）——第六轮配方紧凑复刻 | 3 |

## 测试文件

- `loglog_wbtest.mbt`：T-MEM / T-SE / T-COMPARE / T-FACT2 / T-DUP / T-MERGE / T-CAP（7+ 测试，全部种子化）

## FORMAL（proofmodel/verify.mbtp）

- `cap_reg_in_range(v)`：封顶后 v ∈ [0,31]（require v≥0；两条 lambda ensure）
- 预登记：打包往返/merge 需数组 → RUNTIME

## 判据映射（论文 → 测试）

| 论文 | 测试 |
|---|---|
| §4 "640 bytes in total" | T-MEM 精确字节数 |
| Thm 1(ii) SE=1.30/√m | T-SE 3σ 窗口 |
| §6 对比表（1.30/1.05/1.04 序） | T-COMPARE 多种子均值排序 |
| Fact 2（65%/95% 分位） | T-FACT2 宽容分位数 |
| §2 可观测性（复制无关） | T-DUP 寄存器全等 |
| §6 max-merge | T-MERGE |
| Restriction Rule 5-bit | T-CAP + cap_reg 契约 |

## 明确不实现

Γ 函数精确 α_m（用 α_∞ 常数，论文允许）；碰撞补偿估计器（§5 末，H 足宽无碰撞压力）；HLL 大基数修正之外的第六轮已覆盖部分。
