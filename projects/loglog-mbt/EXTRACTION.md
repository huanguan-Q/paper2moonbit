# S1 算法抽取清单 — LogLog (Durand & Flajolet, ESA 2003)

> 论文：LogLog Counting of Large Cardinalities（INRIA Flajolet 出版服务器全文 10 页）
> 定性：基数估计家族论文（LogLog + SuperLogLog），纯逻辑。**整体可转**。
> 本轮定位：LogLog 家族**与 HLL 对比**（HLL 配方第六轮已验证），新判据：家族对比统计。

## 可转核心（§2/§5 逐行翻译）

| # | 组件 | 论文出处 | 规格 |
|---|------|---------|------|
| C1 | LogLog：前 k 位选桶（m=2^k），余位 ρ(y)=首个 1 位位置（从左 1 起），M(j)=桶内最大 ρ；E = α_m·m·2^(均值 M) | §2 Algorithm | α_m=Γ(−1/m)/((1−2^{1/m})log2·…)；**α_∞=e^{−γ}·√2/2≈0.39701，m≥64 可直接用**（论文明文） |
| C2 | Restriction Rule：寄存器封顶 B = ⌈log₂log₂(Nmax/m)⌉+3；5-bit 寄存器（值 <32） | §4 Thm 2/§5 | N=2^27,m=1024 → B=20，"640 bytes in total" |
| C3 | SuperLogLog Truncation Rule：估计时保留 θ₀=0.7 比例的**最小**寄存器值（m0=θ₀m），E_sll = α_m·m0·2^(保留均值)；经验 SE=1.05/√m | §5 | |
| C4 | max-merge 可合并性：寄存器表逐位 max 合并（§6 "max–merge"） | §6 | |

## 测试判据（全部来自 Thm 1/Fact 1/Fact 2/§6 对比表）

1. **T-MEM**：m=1024、5-bit 寄存器 → **恰好 640 字节**（§4 原文数字）；HLL 6-bit → 768 字节；packed get/put roundtrip
2. **T-SE**（Thm 1(ii)）：n=10⁵ distinct、m=1024、20 种子：LogLog 相对误差 \|err\| ≤ 3×(1.30/√1024)≈12.2%（3σ 窗口，Fact 2 精神）
3. **T-COMPARE**（§6 对比表的统计落地）：同流同种子 20 组：mean\|err\| 排序 **HLL(1.04/√m) < SLL(1.05/√m) < LogLog(1.30/√m)**——理论序在固定种子集上成立即通过
4. **T-FACT2**（Fact 2 精确分位）：SLL 20 种子中 \|err\|≤σ 的比例 ≥ 50%（论文 65%，20 样本宽容）；\|err\|≤2σ ≥ 85%（论文 95%）
5. **T-DUP**：复制流 vs 去重流寄存器全等（"observable independent of replication"）
6. **T-MERGE**：两半流 sketch max-merge == 全流单 sketch 寄存器全等 + 估计一致

## 偏差声明（预登记）

- α_m 用 α_∞=0.39701 常数（论文明文允许 m≥64；Γ 精确式不实现，偏差登记）
- SLL 常数按论文原文用 α_m（非 α_{m0}；原文公式排印含糊处按字面实现并登记）
- 哈希碰撞补偿（§5 末估计器修正）不实现：H=64-bit ≫ H0，碰撞可忽略（论文条件）
- ρ 越界（payload 全 0）按 64 处理后由 5-bit cap 吸收（Restriction Rule 语义）
- HLL 侧复用第六轮已验证配方（α_m 分段 + 小基数线性计数修正），本轮不重复证明其 SE

## FORMAL 候选

- `cap_reg(v)`：5-bit 寄存器封顶契约 v ∈ [0,31]（require v≥0，if-else LIA 直证，同跳表 cap_level 模式）
- 预登记降级：packed get/put 往返、max-merge 需数组 → RUNTIME
