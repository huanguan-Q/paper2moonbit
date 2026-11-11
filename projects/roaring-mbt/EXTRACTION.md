# 来源披露（Extraction & Provenance）— Roaring 位图（容器级 run/array/bitset 编码）

> 本文件为 paper2moonbit 工作流的来源披露记录（补齐于 2026-11-11 合规检查 C-1）。

## 规范来源

- **论文/规范**：arXiv:1603.06549 (Lemire et al.)
- **仓库内依据**：代码注释（'Spec source: arXiv:1603.06549'；4096 阈值容器分层）；moon.mod description 亦标注 Lemire et al.

## 实现性质声明

- 实现为**独立 MoonBit 实现**：算法结构依上述规范来源的公开描述；未复制任何第三方源码
- 判据（测试期望值）取自论文 worked example、定义性性质或对拍 oracle——具体见各测试文件注释标注的 `paper criteria` / `paper Section N`
- 与源项目差异、适用边界见 `README.mbt.md`

## 许可

本包以仓库根 `LICENSE`（MIT）发布；规范来源论文的版权归原作者所有，此处仅作学术引用。
