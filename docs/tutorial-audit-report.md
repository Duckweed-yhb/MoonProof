# 官方教程文档代码块验证报告（第三份）

> 验证对象：MoonBit 官方文档站 `next/tutorial`（`for-go-programmers` 教程 + `cli-quickstart`）
> 验证工具：MoonProof（文档代码块 → 隔离真实编译 → 归因 + 修复建议）
> 验证日期：2026-10-04
> 工具链：MoonBit（本地安装版）

## 一、验证对象与方法

对官方"MoonBit for Go Programmers"教程（`for-go-programmers/index.md`，37 个 MoonBit 代码块）与
CLI 快速开始（`cli-quickstart.md`，1 个代码块）逐块做**真实 `moon check`**。每个代码块被抽取出、
合成进独立隔离工作区、按 MoonProof 默认语义（期望编译通过）验证。共 **38 块**。

## 二、结果汇总

| 文档 | 总块 | 通过 | 失败 | 跳过 |
|---|---|---|---|---|
| `for-go-programmers/index.md` | 37 | 19 | 18 | 0 |
| `cli-quickstart.md` | 1 | 0 | 1 | 0 |
| **合计** | **38** | **19** | **19** | **0** |

失败归因分布：

| 归因 | 数量 | 含义 |
|---|---|---|
| `compile-error` | 17 | 编译报错（多为片段性示例缺标注） |
| `api-changed` | 2 | 用了当前工具链不支持的写法，疑似真 API / 语法变更 |

## 三、失败清单（可追溯）

行号指代码块在源文档中的起始行。错误码为 `moon check` 报错码。

| 文档 | 行号 | 归因 | 错误码 | 说明 |
|---|---|---|---|---|
| `cli-quickstart.md` | 27 | compile-error | 3002 | — |
| `for-go-programmers/index.md` | 56 | compile-error | 3002 | **片段性伪代码**：`impl[T : Trait] ... with ... { ... }` 含 `...` 占位 |
| 同上 | 79 | compile-error | 4074 | — |
| 同上 | 107 | **api-changed** | — | `struct Age(Int)` + `age.0` 字段访问，疑似语法差异 |
| 同上 | 165 | compile-error | 4074 | — |
| 同上 | 234 | compile-error | 4074 | — |
| 同上 | 259 | compile-error | 4074 | — |
| 同上 | 275 | compile-error | 4074 | — |
| 同上 | 297 | compile-error | 4074 | — |
| 同上 | 535 | compile-error | — | — |
| 同上 | 620 | compile-error | — | — |
| 同上 | 798 | compile-error | 4074 | — |
| 同上 | 839 | compile-error | — | — |
| 同上 | 878 | **api-changed** | — | trait 关联函数调用 `T::name()`，疑似语法差异 |
| 同上 | 953 | compile-error | 4032 | — |
| 同上 | 1032 | compile-error | 3002 | — |
| 同上 | 1094 | compile-error | 3001 | — |
| 同上 | 1122 | compile-error | 4020 | — |
| 同上 | 1147 | compile-error | 4020 | — |

## 四、归因分析

抽查失败块原文后，19 个失败块呈现两类成因：

**1. 片段性示例缺显式标注（占多数）**

例如第 56 块：

```moonbit
Enumeration::Variant(random_variable).do_something()
impl[T : Trait] for Structure[T] with some_method(self, other) { ... }
```

这是**演示语法的伪代码**——含 `...` 占位，本就不该作为完整代码编译。MoonProof 默认语义是
"期望编译通过"，这类片段会被如实判为失败。**这不是文档腐坏，而是"文档需要一种标注期望的机制"**
——而 MoonProof 的 `no-check` 标注正是为此设计。官方文档若为这类片段补上 `no-check`（或改写为
可编译的最小完整示例），即可同时保住可读性与可验证性。

**2. 真 API / 语法差异（2 处，建议官方核查）**

- 第 107 块：tuple struct `struct Age(Int)` 的字段访问 `age.0` —— 报 `api-changed`。
- 第 878 块：trait 关联函数调用 `T::name()` —— 报 `api-changed`。

这两块都是相对完整的可编译代码，却用了当前工具链不接受的写法。若确属语法/API 演进，说明
官方教程存在与现行工具链脱节的示例，应更新；这正是 MoonProof 想暴露的"文档腐坏"。

## 五、对官方文档的反馈建议

1. 为 `for-go-programmers/index.md` 中**片段性伪代码块**（如第 56 块）补 `no-check` 标注，
   或改写为可编译的最小完整示例，避免被当作完整代码验证。
2. 核查并更新第 107、878 两处 `api-changed` 示例（tuple struct 字段访问、trait 关联函数调用），
   使其匹配现行工具链语法。
3. 建议官方文档引入"代码块期望标注"约定（MoonProof 已实现 `no-check` / `should-fail` / `run`），
   让示例从"写给人看"升级为"可被 CI 持续验证"。

## 六、局限与说明

- 本报告反映**验证当日**工具链版本下的结果；工具链演进后需重新验证。
- 片段性示例被判定失败是 MoonProof 默认语义的预期行为，不代表官方文档"有错"，
  而是提示文档作者显式标注片段性质。
- 行号为源文档起始行；完整失败诊断（stderr 摘要 + 修复建议）可通过 `--verbose` 复现。
