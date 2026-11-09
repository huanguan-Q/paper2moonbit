# S1 算法抽取清单 — Shapiro et al. 2011《A Comprehensive Study of Convergent and Commutative Replicated Data Types》(INRIA RR-7687)

实现范围：**状态基（state-based）CRDT 第 3 章**（第 2 章理论框架作为设计依据，不实现 op-based 传输层）。

## 核心算法（按论文规格编号）

| 规格 | 名称 | payload | update | query | merge | compare |
|---|---|---|---|---|---|---|
| Spec 6 | G-Counter | `int[n] P`（每副本一项） | `P[g] += 1` | `value = ΣP[i]` | 逐项 max | 逐项 ≤ |
| Spec 7 | PN-Counter | `int[n] P, int[n] N` | 增：P[g]+=1；减：N[g]+=1 | `value = ΣP − ΣN` | 两组向量逐项 max | 逐项 ≤（合取） |
| Spec 8 | LWW-Register | `(x, t)` | `assign(w): x,t := w, now()` | 返回 x | 时间戳大者胜（平局取右参） | t ≤ t' |
| Spec 11 | G-Set | `set A` | `A := A ∪ {e}` | `e ∈ A` | 并集 | ⊆ |
| Spec 12 | 2P-Set | `set A, set R`（墓碑） | add：A∪{e}；remove：pre lookup(e)，R∪{e} | `e∈A ∧ e∉R` | 两组并集 | — |
| §3.3.5 | OR-Set | `(e, tag)` 对集 + 墓碑 | add：加新 tag 对；remove：把**本地观察到**的 e 的 tags 全部入墓碑 | 对集去重后含 e | 对并集 + 墓碑并集（墓碑覆盖的对从对集剔除） | — |

## 数学公式

- G-Counter 偏序：`X ≤ Y ⇔ ∀i: X.P[i] ≤ Y.P[i]`；merge = LUB（逐项 max）
- 收敛定理（Def 2.3/2.4）：merge 需满足**交换律、结合律、幂等性**（半格）→ 任意合并顺序终态一致

## 论文假设 vs 实现决策

1. "payload 不溢出" → 用 Int，测试用小数值
2. "副本集已知" → 固定 n=4 副本（构造参数）
3. OR-Set state-based 规格论文留白 → 按 §3.3.5 文字推导：tag 唯一 + 墓碑只覆盖观察到的 tag → 并发 add 胜（图 14 语义）
4. `now()` 时间戳 → 逻辑时间戳（调用方传入），保证确定性测试

## 测试判据（论文级，S4 直接转测试）

1. **收敛**（核心判据）：任意 merge 顺序下所有副本终态等价（随机合并序列 PBT，固定种子）
2. G-Counter merge 三律：交换/结合/幂等
3. G-Counter 计数正确：n 副本各加 k 次 → value = n·k
4. PN-Counter：value = 增 − 减（可为负）
5. LWW-Register：并发赋值时间戳大者胜
6. 2P-Set：remove 后 re-add 仍然不在集合中（墓碑永久）
7. OR-Set：并发 add/remove 时 **add 胜**（复现论文图 14 场景）；remove 后重新 add 生效（区别于 2P-Set）

## 形式化验证目标（FORMAL 域候选）

- 独立纯证明包（eliasfano 配方）：证明 `max` 的三律（交换/结合/幂等）——半格三律是收敛定理的标量核心，Int 算术可证
- G-Counter 向量级性质由 PBT 覆盖（FixedArray 循环不变量视 probe 结果决定是否上证明）
