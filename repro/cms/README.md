# repro/cms — Count-Min Sketch 复现物

**这不是第 18 个参赛项目，也不发布到 mooncakes。**

这是 2026-11-13「方案 A」的产物：用 `paper2moonbit` v0.3.3 的七阶段纪律，
从论文定义出发**独立重写**一遍 Count-Min Sketch，用于验证工作流本身可复现。

- 归入 `repro/` 而非 `projects/`：不进入 `regress.sh`、不参与发布、不计入 17 包统计
- 判据集合与已交付的 `projects/cms-mbt` **不完全相同**（见 `docs/REPRODUCE.md` 对拍一节）
- 运行：`cd repro/cms && moon test`

过程记录（做了什么、耗时、与已交付实现的差异、这套证据能证明什么/不能证明什么）
见 [`docs/REPRODUCE.md`](../../docs/REPRODUCE.md)。
