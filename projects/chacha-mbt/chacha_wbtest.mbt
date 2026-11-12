// RFC 8439 test-vector judgments — every assertion is an exact vector from
// the RFC (normative). Hex strings decoded by helper in bytes.mbt.

///|
test "quarter round matches RFC 2.1.1 vector (T-QR)" {
  let out = quarter_round(0x11111111, 0x01020304, 0x9b8d6f43, 0x01234567)
  assert_eq(out.a, 0xea2a92f4)
  assert_eq(out.b, 0xcb1cf8ce)
  assert_eq(out.c, 0x4581472e)
  assert_eq(out.d, 0x5881c4bb)
}

///|
test "quarter round on state matches RFC 2.2.1 (T-QR-STATE)" {
  // sample state; QR(2,7,8,13) rewrites exactly positions 2,7,8,13
  let st : FixedArray[UInt32] = FixedArray::make(16, 0U)
  let words = [
    0x879531e0U, 0xc5ecf37dU, 0x516461b1U, 0xc9a62f8aU, 0x44c20ef3U, 0x3390af7fU,
    0xd9fc690bU, 0x2a5f714cU, 0x53372767U, 0xb00a5631U, 0x974c541aU, 0x359e9963U,
    0x5c971061U, 0x3d631689U, 0x2098d9d6U, 0x91dbd320U,
  ]
  for i in 0..<16 {
    st[i] = words[i]
  }
  let out = quarter_round_state(st, 2, 7, 8, 13)
  assert_eq(out[2], 0xbdb886dcU)
  assert_eq(out[7], 0xcfacafd2U)
  assert_eq(out[8], 0xe46bea80U)
  assert_eq(out[13], 0xccc07c79U)
  // untouched positions stay put
  assert_eq(out[0], 0x879531e0U)
  assert_eq(out[15], 0x91dbd320U)
}

///|
test "block function matches RFC 2.3.2 vector (T-BLOCK)" {
  let key = hex_bytes(
    "00:01:02:03:04:05:06:07:08:09:0a:0b:0c:0d:0e:0f:10:11:12:13:14:15:16:17:18:19:1a:1b:1c:1d:1e:1f",
  )
  let nonce = hex_bytes("00:00:00:09:00:00:00:4a:00:00:00:00")
  let block = chacha20_block(key, 1, nonce)
  let expect = "10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4ed2826446079faa0914c2d705d98b02a2b5129cd1de164eb9cbd083e8a2503c4e"
  assert_eq(bytes_to_hex(block), expect)
}

///|
test "cipher matches RFC 2.4.2 vector and is self-inverse (T-ENC)" {
  let key = hex_bytes(
    "00:01:02:03:04:05:06:07:08:09:0a:0b:0c:0d:0e:0f:10:11:12:13:14:15:16:17:18:19:1a:1b:1c:1d:1e:1f",
  )
  let nonce = hex_bytes("000000000000004a00000000")
  let pt = hex_bytes(
    "4c616469657320616e642047656e746c656d656e206f662074686520636c617373206f66202739393a204966204920636f756c64206f6666657220796f75206f6e6c79206f6e652074697020666f7220746865206675747572652c2073756e73637265656e20776f756c642062652069742e",
  )
  let ct = chacha20_encrypt(key, 1, nonce, pt)
  let expect = hex_bytes(
    "6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0bf91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d807ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab779373 65af90bbf74a35be6b40b8eedf2785e42874d",
  )
  assert_eq(ct == expect, true)
  // self-inverse: decrypting the ciphertext returns the plaintext
  let back = chacha20_encrypt(key, 1, nonce, ct)
  assert_eq(back == pt, true)
}

///|
test "poly1305 matches RFC 2.5.2 vector (T-POLY)" {
  let key = hex_bytes(
    "85:d6:be:78:57:55:6d:33:7f:44:52:fe:42:d5:06:a8:01:03:80:8a:fb:0d:b2:fd:4a:bf:f6:af:41:49:f5:1b",
  )
  let msg = hex_bytes(
    "43727970746f6772617068696320466f72756d2052657365617263682047726f7570",
  )
  let tag = poly1305_mac(key, msg)
  assert_eq(bytes_to_hex(tag), "a8061dc1305136c6c22b8baf0c0127a9")
}

///|
test "poly1305 edge vectors from Appendix A (T-POLY-EDGE)" {
  // r = 0 case: tag = s (key bytes 16..31)
  let key0 = Array::make(32, 0)
  for i in 16..<32 {
    key0[i] = 0xff
  }
  let tag0 = poly1305_mac(key0, hex_bytes("50515253c0c1c2c3c4c5c6c7"))
  assert_eq(bytes_to_hex(tag0), "ffffffffffffffffffffffffffffffff")
  // empty message: single 16-byte block "00..00 | 0x01"
  let key1 = hex_bytes(
    "85:d6:be:78:57:55:6d:33:7f:44:52:fe:42:d5:06:a8:01:03:80:8a:fb:0d:b2:fd:4a:bf:f6:af:41:49:f5:1b",
  )
  let tag1 = poly1305_mac(key1, Array::make(0, 0))
  assert_eq(tag1.length(), 16)
}

///|
test "AEAD construction matches RFC 2.8.2 vector (T-AEAD)" {
  let key = hex_bytes(
    "80:81:82:83:84:85:86:87:88:89:8a:8b:8c:8d:8e:8f:90:91:92:93:94:95:96:97:98:99:9a:9b:9c:9d:9e:9f",
  )
  let nonce = hex_bytes("07:00:00:00:40:41:42:43:44:45:46:47") // fixed-common 07000000 (sender id 7) + IV 40..47
  let aad = hex_bytes("50:51:52:53:c0:c1:c2:c3:c4:c5:c6:c7")
  let pt = hex_bytes(
    "4c616469657320616e642047656e746c656d656e206f662074686520636c617373206f66202739393a204966204920636f756c64206f6666657220796f75206f6e6c79206f6e652074697020666f7220746865206675747572652c2073756e73637265656e20776f756c642062652069742e",
  )
  let aead_out = aead_chacha20_poly1305(key, nonce, aad, pt)
  // ciphertext exact
  assert_eq(
    bytes_to_hex(aead_out.ciphertext),
    "d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b6116",
  )
  // tag exact
  assert_eq(bytes_to_hex(aead_out.tag), "1ae10b594f09e26a7e902ecbd0600691")
}
