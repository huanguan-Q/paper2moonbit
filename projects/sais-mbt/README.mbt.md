# sais-mbt

Linear-time suffix array construction by induced sorting — SA-IS
(Nong, Zhang & Chan, DCC 2009). Independently implemented in MoonBit from
the published algorithm framework; correctness judged by definitional
criteria (permutation, sortedness, naive-oracle agreement on random
strings).

- `suffix_array(text)` — rank-encoded SA-IS, sentinel suffix dropped
- `sais_core(values, alphabet_size)` — core over rank-encoded input with
  explicit trailing sentinel 0

Judgments are definitional: SA is a permutation, SA is lexicographically
sorted, and SA agrees with a naive O(n^2 log n) oracle on random strings.

```bash
moon test
```

## Provenance & License

- **Algorithm**: Nong, Zhang & Chan, "Linear Suffix Array Construction by
  Almost Pure Induced-Sorting", DCC 2009 (SA-IS). The algorithm and its
  framework pseudocode are cited from the paper; this implementation is an
  independent MoonBit coding of that published framework.
- **Code**: original MoonBit implementation, Apache-2.0. No code was copied
  from the paper or from any third-party implementation.
- Judgments are definitional (suffix-array math): permutation, sortedness,
  and agreement with a naive O(n^2 log n) oracle on random strings.
