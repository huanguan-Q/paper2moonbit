# chacha-mbt

ChaCha20 stream cipher and Poly1305 MAC with the AEAD_CHACHA20_POLY1305
construction, verified against the normative test vectors of RFC 8439.

- `quarter_round` / `chacha20_block(key, counter, nonce)` — RFC §2.1-2.3
- `chacha20_encrypt(key, counter, nonce, plaintext)` — §2.4 (self-inverse)
- `poly1305_mac(key, msg)` — §2.5 (mod 2^130-5 via core BigInt)
- `aead_chacha20_poly1305(key, nonce, aad, plaintext)` — §2.8

```bash
moon test
```


## Provenance & License

- **Algorithm**: specified in IETF RFC 8439 (Nichols, Jacobson et al.), an
  IETF open standard whose copyright terms permit implementation. Pseudocode
  and test vectors are cited from the RFC; this is an independent MoonBit
  implementation.
- **Code**: original MoonBit implementation, Apache-2.0.
