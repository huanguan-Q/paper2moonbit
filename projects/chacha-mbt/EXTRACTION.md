# S1 算法抽取清单 — ChaCha20 & Poly1305 (RFC 8439)

> 规范：ChaCha20 and Poly1305 for IETF Protocols（IETF RFC 8439，含 §2 全部伪代码 + 测试向量）
> 定性：密码学论文/规范——纯逻辑（ARX + 大整数模运算）。新领域：密码学（第 14 类）。
> **BigInt 能力域 probe**：Poly1305 需要 mod 2^130−5 大整数——moonbitlang/core/bigint
> 在 FORMAL prove 路径的支持度是全新边界（此前只探过 Int/Double/FixedArray）。

## 可转核心（§2.1-2.6 逐行）

| # | 组件 | 规范出处 | 规格 |
|---|------|---------|------|
| C1 | quarter_round(a,b,c,d)：4 行 ARX（+ 模 2^32、^、<<<16/12/8/7） | §2.1 | UInt32 域 |
| C2 | chacha20_block(key,counter,nonce)：常量 "expa nd 3 2-byte by" + key LE 8 词 + counter + nonce LE 3 词；20 轮（10 列 + 10 对角 quarter round）；加原状态；LE 序列化 64 字节 | §2.3 | |
| C3 | chacha20_encrypt(key,counter,nonce,pt)：块计数器递增生成 keystream，XOR 明文；尾块截断 | §2.4 | |
| C4 | Poly1305 mac：clamp r（&0x0ffffffc...）、P=2^130−5、逐 16 字节块 LE+0x01、Acc=((Acc+block)*r)%P、+s 取低 128 位 LE 序列化 | §2.5 | BigInt 域 |
| C5 | AEAD_CHACHA20_POLY1305：block 0 派生 Poly key、pad16、AAD len + CT len LE 块入 MAC | §2.8 | 组合层 |

## 测试判据（RFC 测试向量 = 黄金 worked example）

1. **T-QR**（§2.1.1）：QR(0x11111111,0x01020304,0x9b8d6f43,0x01234567) → (0xea2a92f4,0xcb1cf8ce,0x4581472e,0x5881c4bb) **精确**
2. **T-QR-STATE**（§2.2.1）：QR(2,7,8,13) 应用于示例状态 → 4 个位置精确改写
3. **T-BLOCK**（§2.3.2）：key=00..1f/counter=1/nonce → 序列化块 = `10 f1 e7 e4 d1 3b 59 15 ... 4e 3c 50 a2`（64 字节精确）
4. **T-ENC**（§2.4.2）：同 key/nonce/counter=1 对 "Ladies and Gentlemen..." 明文 → RFC 密文精确；**加解自逆**（XOR 恒等）
5. **T-POLY**（§2.5.2）：key=85d6be78...1b、msg="Cryptographic Forum Research Group"（34B 三块）→ tag a8061dc1305136c6c22b8baf0c0127a9 **精确**
6. **T-POLY-EDGE**（附录 A）：r=0 向量（tag = s）+ 空消息向量
7. **T-AEAD**（§2.8.2）：RFC AEAD 向量密文+tag 精确

## FORMAL probe（BigInt 域）

- P-B1：BigInt 参数契约是否被 .mbt 逻辑编码接受（probe：BigInt 恒等式）
- 预登记：大概率 unsupported（类比 Double 4207）→ 降级 RUNTIME，边界表补 BigInt 行

## 偏差声明（预登记）

- Poly1305 用 moonbitlang/core/bigint（130 位模运算；core BigInt 支持加/乘/模）——非手写 64 位拆分（复杂度换可靠性）
- 附录 A 的 11 条 Poly1305 攻击向量只取前 2 条代表（r=0 与空消息），其余登记不实现
- AEAD 只实现 RFC §2.8 主构造（不做 §2.8.2 之外协议变体）
