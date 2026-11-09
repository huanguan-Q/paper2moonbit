# BLUEPRINT — skiplist-mbt（Pugh 跳表，完整实现）

模块名：`huanguan-Q/skiplist`（无连字符）。单根包（含 Z3 契约，HLL verified.mbt 模式）。

## 文件清单与依赖序

| # | 文件 | 职责 | 依赖 |
|---|------|------|------|
| 1 | `lcg.mbt` | UInt64 种子化 LCG + next_double（复用 rqgm 配方） | — |
| 2 | `skiplist.mbt` | Node/header/NIL 哨兵；Search/Insert/Delete（Fig.2/4 逐行翻译）；randomLevel（Fig.5，p=1/2 位流）；`cap_level` Z3 契约（FORMAL）；不变量检查器（level-1 升序 + 层间子序列） | 1 |
| 3 | `oracle.mbt`（测试内联，不单独成文件） | 有序数组 oracle（二分插入/查找/删除） | — |

## 测试文件

- `skiplist_wbtest.mbt`：T-ORACLE / T-DISTRIB / T-DUP / T-ORDER / T-DEL-SHRINK / T-COST / T-CAP（8+ 测试）

## FORMAL（契约在 skiplist.mbt 内，moon.pkg 启用 proof_enabled）

- `cap_level(run : Int, max_level : Int) -> Int`：if run < max_level-1 { run+1 } else { max_level }，契约 result ∈ [1, max_level]（两条独立 proof_ensure，避免 && 边界）
- 预登记：链有序性需指针图 → RUNTIME；p^k 分布 → RUNTIME 统计

## 判据映射（论文 → 测试）

| 论文 | 测试 |
|---|---|
| Fig.2 Search | T-ORACLE 命中/未命中 |
| Fig.4 Insert（重复 key 更新分支 + 抬层分支） | T-DUP + T-ORACLE |
| Fig.4 Delete（收缩循环） | T-DEL-SHRINK + T-ORACLE |
| Fig.5 randomLevel 分布 | T-DISTRIB |
| §Analysis 期望比较次数 | T-COST |
| 结构不变量（隐含于 Fig.1 语义） | T-ORDER |
| MaxLevel 封顶 | T-CAP |

## 明确不实现

并发版本（[Pug89a]）；search finger/merge/rank 扩展（[Pug89b]）；hashed-consing 持久化变体（§Discussion）。
