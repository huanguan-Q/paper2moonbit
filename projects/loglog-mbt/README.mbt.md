# loglog-mbt

LogLog / SuperLogLog (Durand & Flajolet, ESA 2003) with bit-packed 5-bit registers, plus a HyperLogLog reference (6-bit) for the family comparison.

- `LogLog::new(k~, seed~)` — m = 2^k buckets, alpha_inf constant
- `add(item)` / `estimate()` / `superloglog_estimate()` (theta0 = 0.7 truncation)
- `merge(other)` — max-merge for distributed reducers
- Memory: 1024 buckets of 5 bits = 640 bytes (paper §4 figure, verified by tests)

```bash
moon test
```
