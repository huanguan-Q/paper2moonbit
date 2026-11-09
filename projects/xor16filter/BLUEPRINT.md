# 蓝图 — Xor16 Filter（arXiv:1912.08258）

## 1. 架构
单包库 `huanguan-Q/xor16filter`。两个模块：哈希原语（hash.mbt）与过滤器本体（xor16filter.mbt）。

## 2. 文件清单与依赖序
| 顺序 | 文件 | 职责 | 依赖 |
|---|---|---|---|
| 1 | hash.mbt | murmur64 / rotl64 / reduce / splitmix64 / low32 | 无 |
| 2 | xor16filter.mbt | Xor16 类型、build（剥皮构造+重试）、contains | hash.mbt |
| 3 | xor16filter_test.mbt | 黑盒：成员必中、误报率统计、n=1 边界 | xor16filter.mbt |
| 4 | xor16filter_wbtest.mbt | 白盒：rotl64/reduce/fingerprint 性质 | hash.mbt |

依赖序 = 上表顺序。

## 3. 接口签名（对齐参考实现 xorfilter.h）
```
pub fn build(keys : Array[UInt64]) -> Result[Xor16, String]
pub fn contains(self : Xor16, key : UInt64) -> Bool
struct Xor16 { seed : UInt64; block_length : Int; fingerprints : FixedArray[UInt64] }
```
槽内以 UInt64 存 16 位掩码指纹（未做位打包，见偏差）。

## 4. Config
- 指纹宽度 16 位（xor16），ε ≈ 0.3905 / 2^16 ≈ 5.96e-6
- capacity = 32 + ceil(1.23·n)，向上取整为 3 的倍数；blockLength = capacity/3
- 构造重试 ≤100 次，每次换 splitmix64 种子

## 与论文/参考实现的偏差
1. 指纹未位打包（UInt64 槽），牺牲内存换实现简洁——冒烟测试接受。
2. 未实现第 10 次重试时的排序去重：要求调用方传入无重复 keys，重复时构造失败报错。
3. 剥皮用单一合并工作队列（BFS 全排空），比 C 参考的三队列顺序排空更完备。
4. n=0 与指纹恰为 0 的非成员键的行为与参考实现一致（可能误报 true），文档注明。
