# BLUEPRINT — cms-mbt（Count-Min Sketch，期刊版构造）

模块名：`huanguan-Q/cms`（无连字符）。单根包 + 独立证明包 `proofmodel/`。

## 文件清单与依赖序

| # | 文件 | 职责 | 依赖 |
|---|------|------|------|
| 1 | `lcg.mbt` | UInt64 LCG（Zipf 流与测试随机源） | — |
| 2 | `mix.mbt` | mix64 行级哈希（逐行种子）、`scale_index` 词→行内索引 | — |
| 3 | `cms.mbt` | CMS：new(ε,δ)/new(w,d)、update、point_query、inner_product、range_query（点和）、conservative_update、row_sum | 2 |
| 4 | `zipf.mbt` | 种子化 Zipf(s) 流生成（CDF 二分逆采样） | 1 |

## 测试文件

- `cms_wbtest.mbt`：T-ONE-SIDED / T-ROW-SUM / T-BOUND / T-INNER / T-CU / T-RANGE（6+ 测试）

## FORMAL（proofmodel/verify.mbtp）

- `scale_in_ring/scale_lt_ring`：x % w ∈ [0, w)（require x≥0, w≥1）——第十一轮同款 mod 判据
- 预登记：单侧性/行和守恒需数组 → RUNTIME

## 判据映射（论文 → 测试）

| 论文 | 测试 |
|---|---|
| §3 Update Procedure | T-ROW-SUM（行和=流总量） |
| Thm 1 前半（单侧） | T-ONE-SIDED（全称精确） |
| Thm 1 后半（ε·N 界） | T-BOUND（种子化窗口） |
| Thm 3（内积单侧） | T-INNER |
| §4.3 范围=点和 | T-RANGE |
| 社区 CU 变体 | T-CU（不劣于 CMS） |

## 明确不实现

dyadic 范围优化（§4.3 后半）、quantile/heavy-hitter 应用层（§5）、F0 估计等其余应用（§6）；保守更新按社区公式（来源偏差已登记）。
