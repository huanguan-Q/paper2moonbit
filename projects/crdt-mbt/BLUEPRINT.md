# 蓝图 — crdt-mbt（S2 产出）

## 1. 架构

单根包 `src/`（所有 CRDT 结构互相独立、无循环依赖），加一个独立纯证明包 `proofmodel/`（只有 .mbtp，FORMAL 域半格三律）。确定性随机合并仿真直接在测试文件内实现（固定种子 LCG），不需要 async——状态基 merge 是纯函数。

## 2. 文件清单与依赖序

| 顺序 | 文件 | 职责 | 依赖 |
|---|---|---|---|
| 1 | src/gcounter.mbt | G-Counter（Spec 6）：increment/value/merge/compare | 无 |
| 2 | src/pncounter.mbt | PN-Counter（Spec 7）：复用两组向量 | gcounter 的 max 语义（自含实现） |
| 3 | src/lwwreg.mbt | LWW-Register（Spec 8）：assign/value/merge | 无 |
| 4 | src/gset.mbt | G-Set（Spec 11）：add/lookup/merge | 无 |
| 5 | src/twopset.mbt | 2P-Set（Spec 12）：add/remove(前置 lookup)/lookup/merge | gset 语义 |
| 6 | src/orset.mbt | OR-Set（§3.3.5 推导的 state-based 规格）：add/remove/lookup/merge | 无 |
| 7 | src/*_test.mbt | 各结构单测 + 论文判据测试 | 对应实现 |
| 8 | src/convergence_test.mbt | 收敛判据 PBT：固定种子随机合并图，全部结构终态等价 | 全部 |
| 9 | proofmodel/verify.mbtp | 半格三律 lemma（max 交换/结合/幂等） | 无（纯证明） |

依赖序 = 上表顺序。

## 3. 接口签名（关键）

```moonbit
// G-Counter
pub struct GCounter { priv vec : FixedArray[Int] }        // n 副本，n=4
pub fn GCounter::new(n : Int) -> GCounter
pub fn GCounter::increment(self : GCounter, replica : Int) -> Unit
pub fn GCounter::value(self : GCounter) -> Int
pub fn GCounter::merge(self : GCounter, other : GCounter) -> Unit   // 就地逐项 max
pub fn GCounter::leq(self : GCounter, other : GCounter) -> Bool     // compare

// PN-Counter：priv 两个 GCounter（P 与 N），value() = P.value() - N.value()
// LWW-Register
pub struct LWWReg { priv x : Int; priv t : Int }          // 值域取 Int（MV 语义不实现）
pub fn LWWReg::assign(self : LWWReg, w : Int, ts : Int) -> Unit
pub fn LWWReg::merge(self : LWWReg, other : LWWReg) -> Unit
// G-Set / 2P-Set：元素类型 String，pub(all) enum 或 struct + Array[String]
// 2P-Set::remove 有论文前置条件 lookup(e)——违反时 abort（测试只用例内合法调用）
// OR-Set
// 对集 = Array[(String, Int)]，墓碑 = Array[(String, Int)]，tag 由全局计数器生成
pub fn ORSet::add(self : ORSet, e : String, tag : Int) -> Unit
pub fn ORSet::remove(self : ORSet, e : String) -> Unit    // 本地观察到的 tags → 墓碑
pub fn ORSet::lookup(self : ORSet, e : String) -> Bool
pub fn ORSet::merge(self : ORSet, other : ORSet) -> Unit
```

公开方法一律 `pub fn Type::method(self : T, ..)`；内部类型 `priv`；跨测试经 `@src` 别名（模块名无连字符）。

## 4. Config

- `moon.mod`：name `huanguan-Q/crdt`（无连字符），`preferred_target` 默认（无需 async，保持 wasm）
- 副本数 n=4（构造参数，测试内常量）；PRNG：LCG 固定种子 42
- moon.pkg：根包 `options("proof-enabled" 不开)`；证明独立包 `proofmodel/` 开 proof-enabled（eliasfano 配方：proof_enabled 包不含 GC Array）
