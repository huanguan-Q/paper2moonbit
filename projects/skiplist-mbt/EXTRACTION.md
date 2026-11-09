# S1 算法抽取清单 — Skip Lists (Pugh 1990, CACM 33(6))

> 论文：Skip Lists: A Probabilistic Alternative to Balanced Trees（CACM 版，CMU 课程镜像）
> 定性：概率性有序字典，纯数据结构，无外部依赖。**整体可转**，主线规格先行路由。
> 新领域：概率性数据结构/有序字典（前九轮未覆盖）。

## 可转核心（Figure 2/4/5 伪代码逐行翻译）

| # | 组件 | 论文出处 | 规格 |
|---|------|---------|------|
| C1 | Search：自顶层下降 + 逐层横移，NIL 哨兵 key 上界终止 | Fig. 2 | 比较次数 = 搜索路径长 + 1 |
| C2 | Insert：update 向量记录每层前驱；重复 key 更新 value；新层高于现最大层时 update 补 header 并抬升 list→level | Fig. 4 | |
| C3 | Delete：splice 后若顶层为空则收缩 list→level | Fig. 4 | |
| C4 | randomLevel：lvl:=1; while random()<p && lvl<MaxLevel: lvl++；p=1/2 时可从随机位流生成 | Fig. 5 | P(level≥k)=p^(k-1) |
| C5 | MaxLevel 选取：MaxLevel = L(N)，p=1/2 时 16 容纳 2^16 元素 | §Choosing MaxLevel | |

## 测试判据（全部来自论文）

1. **T-ORACLE**：种子化随机操作序列（insert/search/delete 交错）vs 有序数组 oracle——每步后内容集合全等
2. **T-DISTRIB**：种子化 10⁴ 次 randomLevel（p=1/2）：count(level==1) ∈ [4600,5400]（P=1/2）；count(level≥4) ∈ [1050,1450]（P=1/8）；上限 MaxLevel=16 永不越界
3. **T-DUP**：重复 key 插入更新 value、尺寸不变（Fig.4: x→value := newValue 分支）
4. **T-ORDER**：任意操作序列后 level-1 链严格升序；level k+1 链是 level k 链的子序列（跳表结构不变量）
5. **T-DEL-SHRINK**：清空列表后 list→level 回落至 1（Fig.4 尾部 while 收缩）
6. **T-COST**：n=4096 种子插入后随机搜索的平均比较次数 ≈ L(n)/p + 1/(1−p) + 1（§Analysis；p=1/2, L(4096)=12 → 期望 ≈27，宽松界 [15,60]）
7. **T-CAP**：cap_level(run, max) ∈ [1, max]（RUNTIME + FORMAL 双覆盖）

## FORMAL 候选

- `cap_level(run, max_level)` 契约：结果 ∈ [1, max_level]（if-else 分段 LIA，直证）
- 预登记降级：链有序性/子序列性需指针图，证明层不支持 → RUNTIME oracle 覆盖；p^k 几何分布统计判据 → RUNTIME

## 偏差声明（预登记）

- key/value 取 Int；NIL 哨兵实现为 key=Int 最大哨兵值的共享节点（论文语义：key 大于任何合法 key）
- random() 用种子化 UInt64 LCG（确定性重放）；p=1/2 用随机位流生成（论文明文建议）
- 论文 Figure 1 的示例图因提取乱序无法逐节点复刻，判据改用 oracle 等价测试（语义等价）
