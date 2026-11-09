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
