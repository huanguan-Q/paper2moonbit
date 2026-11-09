# BLUEPRINT — Elias-Fano 编码（arXiv:1206.4300, Vigna 2012）

## 论文判据（S1 抽取）

单调（非严格递增）序列 x[0..n)，值域 [0, u]：
- `l = max(0, floor(log2(u/n)))`（低位长度）；`high(x) = x >> l`
- **低位数组**：n·l 位连续打包
- **高位数组**：对每个 i 在位置 `high(x[i]) + i` 置 1，其余为 0（unary 间隙），总位数 `high(x[n-1]) + n + 1`
- **随机访问 get(i)**：`select1(i)` 定位高位数组第 i 个 1 → `high = pos - i`，低位从 i·l 处读 l 位
- 空间上界：`n·l + 2n + o(n)` 位（论文核心卖点，测试可断言近似界）
- **successor 查询**：next_ge(x) 返回首个 ≥ x 的元素

## 依赖序与文件

1. `bits.mbt`：BitVec（位读写、跨字 field 读写、popcount、select1/select0 线性扫描）——依赖序 1
2. `eliasfano.mbt`：EliasFano 结构 + build（单调校验）/ get / next_ge / length —— 依赖序 2
3. 测试：黑盒规格级（往返、next_ge oracle、单调性、空间界、l 计算）+ 白盒（跨字 field、select）

## 与论文的偏差（记录）

1. **select1/select0 用线性扫描**（词内 popcount 前缀扫描），不做两级 rank/select 索引 → get 为 O(n/64) 而非常数时间；next_ge 用 get 上的二分（O(log n·scan)），非论文的 select 驱动常数时间。冒烟测试聚焦编码正确性，索引加速记为未实现。
2. 序列允许重复值（非严格单调），与 EF 定义一致。
3. 不做迭代器 / 分块 / 流式解码（论文的 index 应用场景）。

## 测试判据（S4 规格先行）

- 往返：`get(i) == xs[i]`（随机 + 边界：n=0/1、全重复、稠密 u≈n、稀疏 u≫n、2 的幂边界）
- next_ge 与线性扫描 oracle 全一致（含越界 → None）
- get 单调非降
- 空间：`total_bits ≤ n·l + 2n + 2`（l=floor(log2(u/n)) 的直接推论）
- build 拒绝非单调输入 → Err
- 已知值：u=2²⁰, n=2¹⁰ → l=10

## 形式化验证（S6 可选分支，本轮补测）

用 `moon prove`（moonbit-proof 路线）证明位操作不变量：对 1 ≤ l < 64，
`(x >> l) << l | (x & mask(l)) == x`（即 encode/decode 的位完整性）。
若求解器不支持符号移位，如实记录该约束。
