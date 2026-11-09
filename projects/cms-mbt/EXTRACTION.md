# S1 算法抽取清单 — Count-Min Sketch (Cormode & Muthukrishnan, J. Algorithms 2005)

> 论文：An Improved Data Stream Summary（期刊 18 页全文，Oxford 托管）
> 定性：概要数据结构，纯逻辑。**整体可转**。新领域：概要/流摘要（第 12 类）。

## 可转核心（§3-4 定义逐行翻译）

| # | 组件 | 论文出处 | 规格 |
|---|------|---------|------|
| C1 | 参数：w = ⌈e/ε⌉, d = ⌈ln 1/δ⌉；d 个两两独立哈希 h_j: {1..n}→{1..w} | §3 Data Structure | 哈希族成员 = 种子化 mix64（逐行种子） |
| C2 | Update：∀j: count[j, h_j(it)] += ct | §3 Update Procedure | |
| C3 | 点查询：â_i = min_j count[j, h_j(i)] | §4.1 | |
| C4 | 内积查询：(â·b)_j = Σ_k count_a[j,k]·count_b[j,k]；â·b = min_j (â·b)_j | §4.2 Thm 3 | |
| C5 | 范围查询 = 点查询求和（不用 dyadic 优化） | §4.3 | |

## 测试判据（全部来自 Thm 1/3 的可确定性化部分 + 社区标准压力分布）

1. **T-ONE-SIDED**（Thm 1 前半，精确）：任意流后对所有物品 est ≥ true（零修复可全称断言）
2. **T-ROW-SUM**（Update 定义的线性推论，精确）：任一行计数和 = 流总量
3. **T-BOUND**（Thm 1 后半，概率判据种子化）：Zipf(1.0) 流 N=10⁵、w=8192（ε≈e/w≈0.000331）、d=5：全物品最大过估 ≤ 3εN（εN≈33）；Top-50 heavy hitter 相对误差 ≤ 5%
4. **T-INNER**（Thm 3 前半精确）：双 sketch 内积估计 ≥ 真实内积（单侧上界全称成立）
5. **T-CU**：保守更新变体（est = min_j count[j,h_j(i)]，count[j][h_j(i)] ← max{count[j][h_j(i)], est+c}）：单侧性保持；**同流下 CU 最大过估 ≤ CMS 最大过估**（CU 不劣于 CMS）
6. **T-RANGE**：范围和 = 点和，单侧上界

## 偏差声明（预登记）

- **保守更新不是本论文正文的算法定义**（源自 Estan-Varghese 谱系/社区标准，HandWiki 公式化）——按社区公式实现并登记来源
- 本期刊版无 Zipf 实验表（早期会议/技术报告版才有）——Zipf 流作为社区标准压力分布，判据用 Thm 1 保证的常数因子窗口
- 哈希族用种子化 mix64（单族成员固定种子），非两两独立族族级统计
- dyadic 范围查询优化不实现（范围和 = 点和已覆盖正确性）

## FORMAL 候选

- 行索引界：h 缩放后 (x % w) ∈ [0, w)，require x≥0/w≥1（mod 推理，第十一轮已证实可证）
- 预登记降级：min-over-rows 单侧性、行和守恒需数组 → RUNTIME oracle 覆盖
