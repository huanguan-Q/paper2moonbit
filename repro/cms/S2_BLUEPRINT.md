# S2 蓝图

## 文件清单（按依赖序）

| 序 | 文件 | 内容 |
|----|------|------|
| 1 | `mix.mbt` | `mix64(UInt64) -> UInt64` 混合函数；`hash_idx(key,row,width,seed) -> Int` |
| 2 | `rng.mbt` | `LCG::new(seed)` / `next_u64()`（确定性流） |
| 3 | `cms.mbt` | `CMS::new(eps,delta,seed)` / `add` / `estimate` / `total` / `merge` |
| 4 | `zipf.mbt` | `gen_zipf(rng, n, keys, skew) -> Array[Int]` 生成偏斜流 |
| 5 | `cms_wbtest.mbt` | T1–T6 六条论文判据 |

## 签名（S5 按此生成）

```
pub struct CMS { width:Int, depth:Int, seed:UInt64, counters:Array[Array[Int]] }
pub fn CMS::new(eps:Double, delta:Double, seed:UInt64) -> CMS
pub fn CMS::add(self:CMS, key:Int, c:Int) -> Unit
pub fn CMS::estimate(self:CMS, key:Int) -> Int
pub fn CMS::total(self:CMS) -> Int          // = 第 0 行求和，不引入可变状态
pub fn CMS::merge(self:CMS, other:CMS) -> Unit
```

## 设计决策（预登记）

- `total` 不做字段，由第 0 行求和导出 → 消除可变状态，merge 天然一致
- 键用 `Int`（论文定义在任意全域上，取整数全域即可）
- 哈希用确定性混合函数近似成对独立；T4 以多种子经验成功率验收
