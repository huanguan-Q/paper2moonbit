# paper2moonbit — 论文判据驱动的 MoonBit 独立实现工作流

> **用 AI 把研究论文变成可编译、可测试、带形式化验证边界的 MoonBit 开源项目。**
> 21 轮实测 · 15 类论文领域 · 17 个项目 · 17 个已发布 mooncakes 包 · 100+ 条工具链实证事实 · 四后端差分矩阵全一致
> 全部实现独立编码，出处全标注，AI 角色全程可追溯。

## 这是什么

`paper2moonbit` 是一套经过 21 轮真实论文试跑打磨的 **AI 原生开发工作流**（Agent Skill）+ **17 个论文判据驱动的 MoonBit 算法项目**。

输入一篇研究论文（PDF/URL），工作流输出：可编译通过 `moon check` 零警告的实现、以论文定理/测试向量/性质为判据的测试套件、`moon prove` 形式化验证目标，以及一份诚实登记所有偏差的抽取清单。

**核心理念**：论文不能只被"翻译"，要被**判据化**——每个实现必须携带可机械判定的验收标准，且明确标注哪些部分来自论文、哪些是偏差、哪些是环境边界。

## 成果一览

| 维度 | 数据 |
|---|---|
| 论文领域 | 15 类：位图、压缩编码、概率估计、过滤器、词法引擎、成员协议、CRDT、搜索调度 harness、文本压缩管线、有序字典、一致性哈希、概要结构、基数估计家族、浮点补偿算术、系统工程（CoDel）、密码学（ChaCha20/Poly1305）、后缀数组（SA-IS） |
| 项目 | `projects/` 下 17 个独立 moon 项目，376 个 .mbt 文件 |
| 测试 | 90+ 论文判据测试（worked example / 定义性判据 / 朴素 oracle 对拍 / 端到端伺服 / property-based） |
| 形式化验证 | Int + div/mod + FixedArray 域 20+ 契约证明；Double/BigInt 域不可用定论（阳性对照确认） |
| 发布 | **17 个** mooncakes.io 公开包（全部项目已发布）：`huanguan-Q/{cms,loglog,xor16filter,roaring,eliasfano,hyperloglog,ziplex,lifeguard,codel,chacha,chash,sais,rqgm,crdt,bwt,skiplist,fpcomp}` |
| 回归 | `regress.sh` 一键全量（check/test/prove 矩阵），两次工具链升级零破坏全量证据 |

## 工作流（七阶段）

```
S0 环境自检 → S1 论文抽取（判据清单 + 偏差预登记）→ S2 蓝图（文件/测试/FORMAL 映射）
→ S3 蓝图确认 → S4 规格先行（测试先于实现）→ S5 生成 → S6 验证闭环
→ S7 质量门（fmt/check 零警告/test 全绿/prove 契约）+ 发布
```

三条实现路由按论文类型自动选择：

1. **主线**（算法/数据结构/解析器/协议，无重型依赖）：直接实现
2. **降级路线**（系统工程类 / 含不可复现组件）：环境 stub 化（RQGM 的 LLM stub、CoDel 的离散事件网络 stub）+ 算法核心全量实现 + 端到端伺服判据
3. **FORMAL 路由**（可证域）：Int + div/mod + FixedArray 契约进 `moon prove`；Double/BigInt 域阳性对照确认不支持，一律 RUNTIME（探针项目 `moonprobe/` 随升级复检）

## 判据哲学

论文判据按可信度分层，全部**预登记**于抽取阶段：

- **规范测试向量**（最强）：RFC 8439 的 ChaCha20 密文、RFC 8289 的 CoDel 状态机——逐字节精确
- **论文 worked example**：BWT 的 abraca→caraab、Skip List 的几何分布统计
- **定义性判据**：SA 是排列且有序、CMS 单侧误差——SA 的数学定义不需要论文许可
- **朴素 oracle 对拍**：O(n²) 参考实现 vs 线性实现，随机流全称一致
- **性质化判据**（quickcheck）：单调性、平滑性、成员封闭
- **端到端伺服**：稳态 min sojourn ≤ TARGET + 利用率 ≥ 0.5（离散事件模拟）

## 复现

```bash
# 全量回归（17 项目 × check/test/prove）
sh regress.sh <workspace>

# 单项目
cd projects/chacha-mbt && moon test    # RFC 8439 全测试向量
cd projects/codel-mbt && moon test     # CoDel 伺服判据
moon prove proofmodel                  # 形式化契约
```

环境：MoonBit toolchain（`curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash`），在 moon 0.1.20261102 与 0.1.20261104 上全量验证 ALL GREEN。

## Provenance 与合规

- **算法出处全标注**：每个项目的 `EXTRACTION.md` 记录论文引用、可转核心、测试判据映射、偏差声明
- **代码独立实现**：判据引用论文，代码为原创 MoonBit（`docs/COMPLIANCE.md` 有逐包出处表与"合规三查"流程）
- **RFC 类项目**：标注 IETF 开放标准版权条款下的实现许可
- **AI 角色全程可追溯**：`docs/EVOLUTION.md` 记录 21 轮的每一步——哪些由 AI 生成、哪些决策由人确认、哪些失败被如何诊断

## 文档

- [`docs/METHODOLOGY.md`](docs/METHODOLOGY.md) — 七阶段流水线与判据哲学详解
- [`docs/EVOLUTION.md`](docs/EVOLUTION.md) — 21 轮演进史：失败、诊断与配方沉淀
- [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) — 合规三查与逐包出处表
- [`docs/BACKEND_MATRIX.md`](docs/BACKEND_MATRIX.md) — 四后端差分测试矩阵（10 项目全一致）
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — 路线图
- [`tooling/moonprobe/`](tooling/moonprobe/) — 证明器能力边界探针（升级后一键复检）
- [`skill/`](skill/) — 可分发的 Agent Skill（SKILL.md + 知识库 + 回归脚本）

## License

- 本仓库代码：Apache-2.0
- 各 mooncakes 包：Apache-2.0（见各包 moon.mod）
- 算法出处见各项目 EXTRACTION.md 与 README 的 Provenance 章节
