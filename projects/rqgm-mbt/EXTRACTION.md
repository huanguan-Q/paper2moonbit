# S1 算法抽取清单 — RQGM (Iacob et al. 2026, arXiv preprint)

> 论文：The Red Queen Gödel Machine: Co-Evolving Agents and Their Evaluators
> （Cambridge / NVIDIA / Flower Labs / MBZUAI / Inria）
> 定性：LLM 智能体进化框架。**整体不可转**（meta-agent/evaluator 是 LLM 过程，EditWorkspace 依赖 LLM 编辑）。
> 但论文明确 "Only the scoring and orchestration harness is fixed"，附录 B 给出完整 Algorithm 1 伪代码
> ——搜索调度 harness 是纯逻辑，LLM 全部在接口后。按降级路线：**实现固定 harness 核心**。

## 可转核心（harness，算法 1 行 1–35）

| # | 组件 | 论文出处 | 性质 |
|---|------|---------|------|
| C1 | 归档树 + clade metaproductivity：CMP(a) = n_C_succ/(n_C_succ+n_C_fail)，clade = 以 a 为根的子树 | §3.1 | 纯逻辑 |
| C2 | ε-best-belief：BBε(a) = I⁻¹_ε(1+S, 1+F)，逆正则化不完全 Beta 函数 | §3.1 | **数值算法**（连分式） |
| C3 | UCB-Air 扩张门：N_t^α ≥ \|T_t\| 则扩张否则评估 | §3.3 | 纯逻辑 |
| C4 | 三级采样：节点 Thompson-over-CMP；role/task 最少评估优先 LeastMeasuredCell | §3.3 | 纯逻辑（RNG 种子化） |
| C5 | 工具记录：z 带 dep(z)（依赖槽位集）+ 生成时刻 criterion 标签 | App. F.1 | 纯逻辑 |
| C6 | 选择性擦除 Erase_m：保留 m∉dep(z) 或 κ_m(z)=κ_new 的记录；重算全部派生统计 | Def. F.2 | 纯逻辑 |
| C7 | 检查点调度 C_B(ρ,h) = {⌊hρ^q⌋}，q ≤ Q | App. F.5 | 纯逻辑 |
| C8 | 评估器替换：anchor 上 BBε 排名，平局 incumbent 胜；替换则 j_m+1 + Erase_m + 重算 CMP | Alg.1 L22–31 | 纯逻辑 |
| C9 | 端点选择：全归档最高 BBε 节点 | Alg.1 L33–35 | 纯逻辑 |

## 接口后不可转（stub 化）

- EditWorkspace（meta-agent LLM 编辑）→ 确定性 stub：按种子生成子节点
- TrainEval/ValEval（LLM 执行任务）→ 固定成功率 Bernoulli stub（种子化 LCG）
- Evaluator/challenger → 固定 anchor 准确率的打分器 stub

## 测试判据（全部来自论文）

1. **T-CMP**：构造树，CMP 值 = 手算合并率；clade 边界正确（根、叶、单链）
2. **T-GATE**：UCB-Air 不变量 \|T_t\| = O(N^α)（运行后断言 |T| ≤ C·N^α，Prop 前提）
3. **T-BB-NUM**：I_x(a,b) 连分式 vs scipy 参考值（1e-9）；BBε 逆往返 |I_{BBε(s,f)}−ε| 容差；BBε 随成功数单调增
4. **T-BB-CONSERV**：BBε ≤ 后验均值（保守下界，Prop. 4 性质）
5. **T-SAMPLE**：种子化 Thompson 采样确定性可复现；LeastMeasuredCell 负载均衡（role/task 计数差 ≤1 后选最小）
6. **T-ERASE**（Def. F.2 语义）：擦除恰移除 dep 含 m 且 κ 过期的记录；**Remark 1 顺序无关**：Erase_m∘Erase_l = Erase_l∘Erase_m（m≠l）；Prop.2 一致性：擦除后派生统计全部来自保留记录
7. **T-SCHED**：C_B(ρ,h) 生成正确（ρ=2, h=1 → 1,2,4,8,…）；**Prop.6 常数界**：总重处理数 ≤ ⌈ρB/(ρ−1)⌉；**Remark 7 对照**：均匀检查点（每 h 步）总重处理 = Θ(B²/h)，实测显著超线性
8. **T-REPLACE**：平局 incumbent 胜（Rem.3 不发生无谓擦除）；替换后新评估器 anchor BBε ≥ incumbent（never-worse）
9. **T-HARNESS**：全 Algorithm 1 仿真（stub 评估器），预算 B 后：(a) 端点 = 全归档 BBε 最大节点；(b) 替换发生时 epoch 向量前进 + 槽位旧记录数为 0；(c) 界定恢复计数符合 Prop.6 界

## FORMAL 域候选（Int 域，Z3 可证）

- CMP 单调性：加一个成功不降低 CMP —— (a+m)·b ≤ (b+m)·a 的交叉相乘形式（LIA）
- 擦除过滤的长度界：erase 后长度 ≤ 原长度
- 检查点几何和界（整数特例 ρ=2：sum_{q≤Q} 2^q = 2^{Q+1}−1 ≤ 2B）—— 2^q 非线性，可能 unsupported，降级 RUNTIME

## 偏差声明（预登记）

- 时间/预算抽象为整数评估次数；时间戳用逻辑计数器
- Beta 采样用 Erlang 分解（参数为正整数时精确等价：Beta(i,j) = G_i/(G_i+G_j)，G_k 为 k 阶 Erlang）——仅适用于 BB 采样参数 1+S, 1+F 全为整形的场景，正好覆盖本文全部用法
- LLM 组件 stub 化，仅验证 harness 逻辑，不声称复现论文实验结果
