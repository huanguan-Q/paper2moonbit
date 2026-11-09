# 蓝图 — Roaring Bitmap（arXiv:1603.06549 核心子集）

## 1. 架构
单包库 `huanguan-Q/roaring-mbt`。三层：ArrayContainer / BitmapContainer（叶子）、Roaring（两级索引 + 分派）。

## 2. 文件清单与依赖序（同包内文件，依赖序指导生成顺序）
| 顺序 | 文件 | 职责 | 依赖 |
|---|---|---|---|
| 1 | roaring_test.mbt | 规格级测试（先行，S4 规格即测试） | 无（最后通过） |
| 2 | container.mbt | ArrayContainer + BitmapContainer + Container enum：contains/add/remove/基数十进制/互相转换 | 无 |
| 3 | roaring.mbt | Roaring 类型：排序 key 表 + 容器表、二分定位、add/contains/remove 分派与阈值转换 | container.mbt |
| 4 | roaring_wbtest.mbt | 白盒：二分定位性质、容器内部不变量 | container/roaring |

## 3. 接口签名（论文 §2 口径）
```
pub struct Roaring  // 32-bit 精确成员位图
pub fn Roaring::new() -> Roaring
pub fn Roaring::add(self, value : UInt32) -> Unit      // 幂等
pub fn Roaring::remove(self, value : UInt32) -> Unit
pub fn Roaring::contains(self, value : UInt32) -> Bool
```
内部表示：key/值用 Int（0..65535）承载 16 位语义；容器枚举 `Arr(排序值表, len)` / `Bmp(1024×UInt64, 基数)`。

## 4. Config / 论文判据
- 阈值 4096：Arr 满升 Bmp；Bmp 基数删至 ≤4096 降回 Arr（论文 §2.2/§2.3）
- 精确成员：无误报
- 容器 key 表严格升序；Arr 值严格升序且无重复
- 容器删空后从 key 表移除

## 与论文的偏差
1. 不实现 v4 的 RunContainer（RLE 段）与序列化——核心两级结构完整。
2. 内部值/键用 Int 而非 UInt16 位打包（语义等价，内存非紧凑）。
3. 不实现 and/or/xor 等集合运算（仅 add/remove/contains）。
