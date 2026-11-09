# S1 算法抽取清单 — BWT (Burrows & Wheeler 1994, SRC-RR-124)

> 论文：A Block-sorting Lossless Data Compression Algorithm（8 页核心版，JHU 镜像）
> 定性：纯字符串算法 + 自适应编码，无 LLM/外部依赖。**整体可转**，主线规格先行路由。
> 新领域：文本压缩管线（字符串变换 + 自适应编码），前八轮未覆盖。

## 可转核心

| # | 组件 | 论文出处 | 规格 |
|---|------|---------|------|
| C1 | BWT 正变换：循环旋转排序 → L（末列）+ I（原串行号） | Alg. C | S='abraca' → L='caraab', I=1 |
| C2 | BWT 逆变换：C/P/T 数组 + 从 I 回溯重建 | Alg. D + §4.2 伪代码 | T[i]=P[i]+C[L[i]]；例 T=(4 0 5 1 2 3)；重建 S='abraca' |
| C3 | Move-to-Front 编码/解码（字母表序初始列表） | Alg. M/W | Y=[a,b,c,r] 起，L='caraab' → R=(2 1 3 1 0 3) |
| C4 | zero-run 编码（M2 熵编码的替代变体） | §5 变体 | R 中零游程 → (RUN 标记, 长度)；非零值直传 |
| C5 | 端到端管线 compress/decompress | Alg. C+M+§5 | 无损往返 + 压缩率判据 |

## 判据（全部来自论文）

1. **T-C-FWD**：'abraca' → L='caraab'、I=1（论文 §Alg.C worked example）
2. **T-C-TVEC**：L='caraab' 的 T 向量 = (4 0 5 1 2 3)（§Alg.D D2）
3. **T-D-INV**：逆变换恢复 'abraca'（§Alg.D D3）
4. **T-MTF**：L='caraab' → R=(2 1 3 1 0 3)（§Alg.M M1）；W 解码还原 L（§Alg.W W2）
5. **T-BWT-RT**：roundtrip 多形态串：重复文本（mississippi×8）、全同字符、单字符、二值交替——含排序平局稳定性（等价旋转的行序不影响 L/I 语义，但 I 必须指向原串）
6. **T-ZR**：zero-run 编解码 roundtrip；全零串压缩长度 < 原长
7. **T-E2E**：BWT→MTF→zero-run 压缩 → 逆管线无损还原；重复文本压缩输出 < 原长（压缩有效判据）
8. **T-PERM**：F=sort(L) 是 L 的排列（计数一致）——间接由 roundtrip 保证

## FORMAL 候选（Int 域 LIA）

- 桶分区恒等式：前缀和边界 s2+c2 == N（逆变换 C 数组的构造不变量）
- T 下标有界：p < cnt → c_pre+p < c_pre+cnt（T[i] 落桶内）
- 预登记降级：旋转比较性质/排列性质需数组，证明层不支持 → RUNTIME 测试覆盖

## 偏差声明（预登记）

- 字符集：Array[Int] 字符码（0–255），不做字节级序列化，管线输出为结构化 (L,I) / (R,I) 内存表示
- 熵编码：论文 M2 的 Huffman/算术编码不实现，以 zero-run 变体（§5 明文描述）替代，最终输出为 Int 数组
- 排序：朴素旋转比较排序（O(n²log n)），论文 §4.1 的后缀树/快排加速属性能优化非正确性核心，不实现
