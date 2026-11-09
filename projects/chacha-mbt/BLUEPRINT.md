# BLUEPRINT — chacha-mbt（ChaCha20 + Poly1305，RFC 8439 测试向量判据）

模块名：`huanguan-Q/chacha`（无连字符）。单根包 + 独立证明包 `proofmodel/`。

## 文件清单与依赖序

| # | 文件 | 职责 | 依赖 |
|---|------|------|------|
| 1 | `chacha.mbt` | quarter_round（UInt32 ARX）、state setup、block function（20 轮）、encrypt/decrypt | — |
| 2 | `poly.mbt` | Poly1305：clamp、逐块 BigInt 累积（P=2^130−5）、tag 序列化；AEAD 组合（poly key 派生 + pad16 + len 块） | 1 |
| 3 | `bytes.mbt` | LE 编解码辅助（u32 le bytes、bytes→BigInt） | — |
| 4 | `proofmodel/verify.mbtp` | P-B1 BigInt 契约 probe | — |

## 测试文件

- `chacha_wbtest.mbt`：T-QR / T-QR-STATE / T-BLOCK / T-ENC / T-POLY / T-POLY-EDGE / T-AEAD（7+ 测试，全部 RFC 向量精确判定）

## 判据映射（RFC → 测试）

| RFC | 测试 |
|---|---|
| §2.1.1 quarter round 向量 | T-QR（32-bit 精确） |
| §2.2.1 state quarter round | T-QR-STATE |
| §2.3.2 block function 向量 | T-BLOCK（64B 精确） |
| §2.4.2 cipher 向量 + 自逆 | T-ENC |
| §2.5.2 Poly1305 向量（三块演算） | T-POLY（tag 精确） |
| 附录 A（r=0、空消息） | T-POLY-EDGE |
| §2.8.2 AEAD 向量 | T-AEAD |

## 明确不实现

附录 A 11 条 Poly1305 攻击向量（取 2 条代表）；§4 安全考量讨论；XChaCha20/HChaCha20（另一 RFC）；流式增量 API（一次性接口足够）。
