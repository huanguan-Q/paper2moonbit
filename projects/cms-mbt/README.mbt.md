# cms-mbt

Count-Min Sketch (Cormode & Muthukrishnan, J. Algorithms 55(1), 2005).

- `CMS::new(w~, d~, seed~)` / `CMS::with_params(eps~, delta~, seed~)`
- `update(item, c)` — add c to one cell per row (RFC-style §3 procedure)
- `point_query(item)` — min over rows (Thm 1: one-sided, err <= eps*N w.h.p.)
- `inner_product(a, b)` / `range_query(l, r)`
- `conservative_update` — community CU variant (never worse than plain CMS on point queries)

Tests carry the paper judgments: one-sidedness, row-sum conservation, Thm 1 windows on Zipf streams.

```bash
moon test
```

## Provenance & License

- 出处：见本包 EXTRACTION.md（Count-Min Sketch, Cormode & Muthukrishnan 2005 判据）
- 独立实现声明与判据来源详见同目录 `EXTRACTION.md`；许可证随仓库根 `LICENSE`（MIT）。
