# BLUEPRINT — ZipLex 词法分析引擎（arXiv:2510.18479, Chassot & Kunčak）

## 论文判据（S1 抽取）

- **Brzozowski 导数**：`D_c` 按标准规则求导（union 逐项、concat 左导数右拼接 + nullable 左侧时并入右导数、star 为 D_c(r)·r*）
- **Maximal munch**（最长匹配）：每步保持全部规则的当前导数；记录"最远的 nullable 位置"及该位置上**优先级最高**（下标最小）的 nullable 规则；导数全灭或输入耗尽时在此发射 token
- **规则优先级**：同长度匹配取靠前规则；更长的匹配胜过优先级（ocamllex 语义）
- **可逆性（论文核心贡献）**：`print(lex(s)) == s`（前提：s 的每个字符都被某条规则覆盖——separability 简化版）
- **Memoization**：导数状态空间有限（smart constructors 保证），缓存 (regex, char) → 导数实现线性时间
- **错误语义**：某位置无可匹配前缀 → 词法错误

## 路由决策（对 SKILL.md 的修正素材）

论文贡献是 **lexer 引擎算法本身**（运行时对 Regex 值求导的解释器），非"给定文法生成 lexer"——**moonlex/ulex 不适用**（生成 DFA 会绕开论文贡献），故手写。SKILL.md 的"解析器类论文 → lexgen"路由应细化为：论文给出词法文法要生成 lexer → moonlex；论文贡献为 lexer/解析引擎算法 → 纯手写。

## 依赖序与文件

1. `regex.mbt`：Regex AST（REmpty/REps/RChar/RRange/RUnion/RConcat/RStar，derive(Eq,Hash)）+ smart constructors（union 扁平去重、concat/star 折叠）+ nullable + derivative + render（规范字符串，兼作 memo 键与调试）——依赖序 1
2. `lexer.mbt`：Token/Rule + `lex(rules, input) -> Result[Array[Token], String]`（maximal munch + 优先级 + HashMap memo）+ `print(tokens)` ——依赖序 2
3. 测试：白盒（导数代数性质、折叠性质）+ 黑盒规格级（maximal munch、优先级、可逆 roundtrip、错误、JSON 形态词法）

## 与论文的偏差（记录）

1. **无 Huet zipper**：zipper 是论文的性能优化（避免导数膨胀），冒烟版用 smart constructors + memo 达成正确性；记为未实现
2. **separability 简化**：论文的可逆性证明依赖 token 序列可分性条件与 R-Path 谓词；本实现直接在 token 中保留 lexeme，print = lexeme 拼接，roundtrip 在"规则覆盖全部字符"前提下精确成立
3. memo 键用 render 字符串（结构规范化后），非论文的验证过的命令式哈希表
