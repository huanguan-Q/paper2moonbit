# BLUEPRINT — bwt-mbt（BWT 压缩管线，完整实现）

模块名：`huanguan-Q/bwt`（无连字符）。单根包 + 独立证明包 `proofmodel/`（同 crdt/rqgm 模式）。

## 文件清单与依赖序

| # | 文件 | 职责 | 依赖 |
|---|------|------|------|
| 1 | `bwt.mbt` | forward：循环旋转排序 → (L, I)；inverse：§4.2 伪代码逐行翻译（C/P/T 数组 + 从 I 回溯） | — |
| 2 | `mtf.mbt` | MTF 编码（Alg. M）/解码（Alg. W），字母表 256 码位，初始列表 0..255 | — |
| 3 | `zerorun.mbt` | R 的零游程编码/解码（§5 变体：RUN 标记 + 长度，非零直传） | — |
| 4 | `pipeline.mbt` | compress：BWT→MTF→zero-run（输出 L,I → R → ZR）；decompress 逆序还原 | 1-3 |

## 测试文件（白盒 wbtest）

- `bwt_wbtest.mbt`：T-C-FWD / T-C-TVEC / T-D-INV / T-BWT-RT（6+ 串形态）
- `mtf_wbtest.mbt`：T-MTF（论文 R 向量 + roundtrip + 边界：空串、单字符、全同）
- `zerorun_wbtest.mbt`：T-ZR
- `pipeline_wbtest.mbt`：T-E2E + 压缩有效性（重复文本压缩输出 < 原长）

## FORMAL（proofmodel/verify.mbtp）

- `bucket_partition(c0,c1,c2,n,s1,s2)`：s1==c0, s2==c0+c1, c0+c1+c2==n → s2+c2==n
- `t_index_bounded(p,c_pre,cnt)`：p>=0, p<cnt → c_pre+p >= c_pre && c_pre+p < c_pre+cnt
  （写成两条独立 proof_ensure 避免 && 边界，或封装 predicate）

## 判据映射（论文 → 测试）

| 论文 | 测试 |
|---|---|
| Alg.C example | T-C-FWD: L='caraab', I=1 |
| Alg.D D2 T 向量 | T-C-TVEC |
| Alg.D D3 / §4.2 | T-D-INV + roundtrip |
| Alg.M R=(2 1 3 1 0 3) | T-MTF |
| §5 zero-run 变体 | T-ZR |
| 压缩有效性（Table 2 精神） | T-E2E 长度判据 |

## 明确不实现

Huffman/算术编码（M2，以 zero-run 替代，偏差已登记）；后缀树/快排加速（§4.1，性能优化非正确性核心）；字节级流序列化。
