# chash-mbt

Consistent hashing (Karger et al., STOC 1997 §4.2): the closest-point
ranged hash family with bucket replication — the paper construction, not the
clockwise-ring engineering variant.

- `RangedHash::new(seed~, points_per_bucket~)` / `add_bucket` / `remove_bucket`
- `assign(item)` — f^V(i), nearest bucket point (Thm 4.1.1 monotone)
- Property tests via moonbitlang/core/quickcheck (member + smoothness)

```bash
moon test
```

## Provenance & License

- 出处：见本包 EXTRACTION.md（连续哈希判据来源）
- 独立实现声明与判据来源详见同目录 `EXTRACTION.md`；许可证随仓库根 `LICENSE`（MIT）。
