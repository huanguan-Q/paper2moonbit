# S1 算法抽取清单 — Consistent Hashing (Karger et al., STOC 1997)

> 论文：Consistent Hashing and Random Trees（MIT 作者主页全文 10 页版）
> 定性：分布式缓存协议的理论核心——ranged hash family，纯逻辑。**整体可转**。
> 新领域：分布式系统算法（第 11 类）。
> ⚠ 关键澄清：**本文构造是"单位区间最近点"，不是后来工程界流行的"环形顺时针后继"**——
> 按论文实现，不做工程变体（偏差声明：不实现 §4.3 的分段子树 O(1) 加速，用二分近似）。

## 可转核心（§4.2 构造 + §4.4 定义逐行翻译）

| # | 组件 | 论文出处 | 规格 |
|---|------|---------|------|
| C1 | 双随机映射 r_B（桶点）/ r_I（物品点）到单位区间；桶复制 K=α·log(C) 个点 | §4.2 | 种子化 multiply-shift 哈希族成员 |
| C2 | 指派 f^V(i) = argmin_{b∈V} \|r_B(b) − r_I(i)\|，要求 f^V(i) ∈ V | §4.1 Def | 最近点二分查找 |
| C3 | 视图增删桶：加/删桶 = 增/删其 K 个点，其余物品指派不变 | §4.2 | |
| C4 | Monotonicity：V1⊆V2 且 f^V2(i)∈V1 ⇒ f^V1(i)=f^V2(i)（物品只在新桶间移动，不在旧桶间移动） | §4.1 Def + Thm 4.1.1 | 直接可测 |

## 测试判据（全部来自论文 Thm 4.1 / §4.4）

1. **T-MEMBER**：任意视图下 f^V(i) ∈ V（ranged hash 定义要求）
2. **T-MONO**：随机视图对 V1⊂V2 × 200 物品 × 多轮种子：monotonicity 逐对成立；特例——加桶后所有发生变化的指派都指向**新桶**（"item may move from an old bucket to a new bucket, but not from one old bucket to another"）
3. **T-SMOOTH-ADD**：n 桶 → n+1 桶：重映射分数 ≤ C/(n+1)（Thm 4.1.2 balance ⇒ smoothness："expected fraction of objects that must be moved is the minimum needed to maintain a balanced load"；宽松界 ≤ 4/(n+1)）
4. **T-SMOOTH-REMOVE**：删桶 b 只影响原指派给 b 的物品
5. **T-BALANCE**：16 桶 × 10⁴ 物品：每桶份额 ≤ 4/16（Thm 4.1.2 O(1/\|V\|) 高概率；窗口放宽至常数因子 4）
6. **T-REPL**：单点桶（K=1）与 K=8 复制桶在同一种子下平衡对比——复制的动机判据（§4.2 "actually need more than one point"）；确定性种子下断言 K=8 的最大份额 < K=1 的最大份额

## FORMAL 候选

- `scale(x, ring)`：点缩放 (x % ring + ring) % ring ∈ [0, ring)——require x 任意/ring≥1，mod 推理 probe；若证明层不支持则降级 RUNTIME（预登记）
- 距离 min2 上界：result ≤ a && result ≤ b（两条 ensure，lambda 形式）

## 偏差声明（预登记）

- 哈希族成员用种子化 splitmix 式混合（论文要求 log(C)-way independent 随机映射——单族成员固定种子即可满足判据测试）
- 单位区间离散化为 Int 环 [0, 2^30)，距离线性（无环形回绕——论文 §4.2 就是线性区间）
- §4.3 的分段子树 O(1) 期望加速不实现，指派用二分 O(log P)（正确性等价，性能偏差登记）
- spread/load 的 Chernoff 高概率界不直接测（需多哈希函数族统计），以 balance + monotonicity 判据覆盖核心
