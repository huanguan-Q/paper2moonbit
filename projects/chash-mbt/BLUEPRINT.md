# BLUEPRINT — chash-mbt（Karger 一致性哈希，论文构造）

模块名：`huanguan-Q/chash`（无连字符）。单根包 + 独立证明包 `proofmodel/`。

## 文件清单与依赖序

| # | 文件 | 职责 | 依赖 |
|---|------|------|------|
| 1 | `mix.mbt` | splitmix 式 UInt64 混合（哈希族成员）；`scale_point` 环缩放 | — |
| 2 | `ring.mbt` | RangedHash：桶注册（每桶 K 个点）+ 全点有序表 + `assign`（最近点二分）+ add/remove bucket；`distance` 线性距离 | 1 |
| 3 | `proofmodel/verify.mbtp` | scale 点域界（mod probe，失败即降级 RUNTIME 并登记）；min2 上界 | — |

## 测试文件

- `chash_wbtest.mbt`：T-MEMBER / T-MONO / T-SMOOTH-ADD / T-SMOOTH-REMOVE / T-BALANCE / T-REPL（6+ 测试，全部种子化确定性）

## 判据映射（论文 → 测试）

| 论文 | 测试 |
|---|---|
| §4.1 f^V(i) ∈ V | T-MEMBER |
| Thm 4.1.1 monotone（含"只在旧→新桶移动"推论） | T-MONO |
| §4.4 smoothness（Thm 4.1.2 平衡推论） | T-SMOOTH-ADD/REMOVE |
| Thm 4.1.2 balance O(1/\|V\|) | T-BALANCE |
| §4.2 复制动机 | T-REPL |

## 明确不实现

§4.3 分段子树 O(1) 加速（二分替代，性能偏差）；spread/load Chernoff 统计判据；§2/§3 的随机树缓存协议主体（本文只转化 §4 一致性哈希核心）。
