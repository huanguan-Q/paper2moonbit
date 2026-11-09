# BLUEPRINT — fpcomp-mbt（浮点补偿算术 + Double 域 FORMAL 压测）

模块名：`huanguan-Q/fpcomp`（无连字符）。单根包（FORMAL probe 用主包 .mbt 契约路径，跳表轮先例）。

## 文件清单与依赖序

| # | 文件 | 职责 | 依赖 |
|---|------|------|------|
| 1 | `lcg.mbt` | UInt64 LCG（随机 Double 流） | — |
| 2 | `fpcomp.mbt` | fast_two_sum（\|a\|≥\|b\| 前提）、two_sum、sterbenz_sub（x/2≤y≤2x 前提）、naive_sum、kahan_sum（Thm 8 伪代码逐行）；**Double 域 FORMAL probe 契约** | 1 |
| 3 | `bits.mbt`（并入 fpcomp 或独立小文件） | Double↔UInt64 位重解释（位精确比较基础设施） | — |

## 测试文件

- `fpcomp_wbtest.mbt`：T-KAHAN-EXACT / T-ID-CONSIST / T-STERBENZ / T-NAIVE-GAP / T-REINTERP（5+ 测试）

## FORMAL（主包契约 probe，位于 fpcomp.mbt）

- P1/P2 见 EXTRACTION：Double 参数契约 probe；unsupported 即删除契约、降级 RUNTIME，并在知识库登记"Double 域 FORMAL 不可用"边界事实

## 判据映射（论文 → 测试）

| 论文 | 测试 |
|---|---|
| Thm 8 Kahan 求和 | T-KAHAN-EXACT（2^53+1000 位精确强判据） |
| Thm 8 vs naive | T-NAIVE-GAP |
| FastTwoSum/TwoSum 恒等式 | T-ID-CONSIST |
| Sterbenz 引理 | T-STERBENZ |
| 位比较基础设施 | T-REINTERP |

## 明确不实现

TwoProduct/Dekker split（溢出 flag 语义不可控）；扩展精度软浮点（double-double 加法链可作后续轮）；Theorem 12 三角形公式等应用层（§Systems Aspects）。
