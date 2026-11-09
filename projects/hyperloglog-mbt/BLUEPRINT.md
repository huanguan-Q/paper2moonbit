# BLUEPRINT — HyperLogLog (Flajolet et al., DMTCS 2007) → MoonBit × instinct-driven CAPT

论文：《HyperLogLog: the analysis of a near-optimal cardinality estimation algorithm》
Flajolet, Fusy, Gandouet, Meunier，DMTCS 2007。第六轮试跑：补测 paper2moonbit 的
instinct-driven-moonbit 主线（Contract + Z3 生成，前五轮均为手写代码）。

## 算法抽取（论文判据）

1. 寄存器更新：hash 低 p 位选寄存器 j，其余位取 rho（最左 1 位位置，1-based）
2. 原始估计：E = α_m · m² / Σ 2^{-M[j]}，α_m = 0.7213/(1+1.079/m)
3. 小基数修正：E ≤ 2.5m 且 V（空寄存器数）> 0 → 线性计数 m·ln(m/V)
4. 标准误差：σ = 1.04/√m

## CAPT 验证分层（C1 裁决）

🟢 FORMAL-VERIFIED（Int + div/mod + for + FixedArray，避开 UInt64 位运算与 Double）：
- `rho(x, bits)`：后置 1 ≤ r ≤ bits+1；循环不变量
- `update_reg(old, v, bits)`：后置 r ≥ old && r ≥ 1
- `register_of(hash, m)`：后置 0 ≤ r < m

🟡 RUNTIME-VERIFIED（Double + @math.ln 降级域）：
- `count()`：调和平均 + α_m + 线性计数修正
- 论文判据测试：n=1..1000 误差、10^5 元素 σ 界、空 HLL = 0

## 依赖序

1. `verified.mbt` — FORMAL 域函数（where contracts）+ probe 先行
2. `hll.mbt` — HLL 主体（UInt64 运行时位运算 + FixedArray 寄存器 + Double 估计）
3. 测试 — 白盒（内部性质）+ 黑盒（论文判据）+ demo

## 范围边界

- 不做稀疏编码变体、EchLogLog/LogLog-Beta 对比实验
- 误差界测试用固定 seed 确定性验证（非统计断言）
