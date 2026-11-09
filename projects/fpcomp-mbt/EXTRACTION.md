# S1 算法抽取清单 — Goldberg 1991 浮点（深度压测轮：Double 域 FORMAL）

> 论文：What Every Computer Scientist Should Know About Floating-Point Arithmetic
> （Goldberg, ACM Computing Surveys 1991；Oracle 合法托管 HTML 全文）
> 定性：浮点误差分析综述。可转核心 = 论文 Theorem 8 + 补偿算术标准恒等式。
> **本轮压测目标：Double 域 FORMAL probe**——知识库 FORMAL 域只验证过 Int+div/mod，
> Double 能否走 Z3 契约是完全未知的边界，本轮无论正负结果都是新边界事实。

## 可转核心

| # | 组件 | 论文出处 | 规格 |
|---|------|---------|------|
| C1 | FastTwoSum：\|a\|≥\|b\| 时 s=a⊕b，e=(s−a)−b 精确捕获舍入误差，a+b=s+e（实数恒等） | Thm 8 的 C 项构造（(T−S)−Y）；Møller/Knuth 谱系，来源登记 | |
| C2 | TwoSum（无序版）：s=a⊕b；x=s−a; y=s−x; bb=y−b; e=(a−x)−bb | Dekker 1971 谱系，来源登记 | |
| C3 | Sterbenz 引理：x/2 ≤ y ≤ 2x ⟹ fl(y−x) = y−x 位精确 | Sterbenz 1974 书（Goldberg §benign cancellation 引用谱系） | |
| C4 | **Kahan 求和（Theorem 8 全伪代码）**：Y=X[j]−C; T=S+Y; C=(T−S)−Y; S=T；每 summand 扰动 ≤2ε vs naive nε | 论文 Theorem 8 | |

## 测试判据

1. **T-KAHAN-EXACT**（Theorem 8 强判据，位精确）：流 = 2^53 后接 1000 个 1.0：naive 和 = 2^53（全部小项被舍入吃掉），Kahan 和 = 2^53+1000 **位精确**（补偿逐项捕获）
2. **T-ID-CONSIST**（恒等式弱判据，全称）：随机 Double 对（含极端尺度差）：fl(s+e) == fl(a+b)（位比较）；TwoSum 与有序 FastTwoSum 的 e 位相等
3. **T-STERBENZ**：x/2≤y≤2x 条件下 fl(y−x) == y−x 位精确（构造 + 随机窗内对）
4. **T-NAIVE-GAP**（Theorem 8 对比）：随机大流 naive 误差单调增长、Kahan 有界——同流 \|kahan−naive\| > 0 且 Kahan 估计更接近排序参考（宽松）
5. **T-REINTERP**：Double 位模式往返 reinterpret 自洽（位比较基础设施自检）

## FORMAL probe（本轮核心，结果无论正负均入路由表）

- P1：Double 参数 lemma 是否被 .mbt 契约路径解析/接受
- P2：若接受，Z3 能否证 Double 域平凡界（如 |fast_two_sum 结果| 相关——甚至 probe result == fl 语义）
- 预登记：大概率 unsupported（知识库 FORMAL 域=Int+div/mod+FixedArray）→ 降级 RUNTIME 并登记"Double 域不可证"边界

## 偏差声明（预登记）

- FastTwoSum/TwoSum/Sterbenz 的出处为 Møller/Knuth/Dekker/Sterbenz 谱系（Goldberg 正文引用但未给算法名与完整伪代码，仅 Thm 8 使用其构造）——按补偿算术标准文献实现，来源逐条登记
- TwoProduct（Dekker split）选做不进本轮判据（wasm 乘法溢出 flag 语义不可控）
- 假设 MoonBit 编译器对 Double 运算保持 IEEE 严格语义（不做 unsafe 优化）——位精确判据本身即是该假设的回归探针
