# MoonProof 生态审计：第三方库 README 可复现性（oboard/eval）

## 审计对象

- 项目：`oboard/moonbit-eval`（mooncakes 包 `oboard/eval`，一个 MoonBit 语言解释器）
- 来源：GitHub 仓库 README（`main` 分支）
- 日期：2026-10-04
- 方法：MoonProof `docs` 模式扫描 README 的全部 `moonbit` 代码块，在最小合成环境中真实编译

## 结果

| 块 | README 章节 | 归因 | 首个错误 |
|---|---|---|---|
| 1 | Quick Start | compile-error | `MoonBitVM()` 未定义 → Cannot infer the type |
| 2 | Compile and Run | compile-error | `MoonBitVM()` / `compile` 未定义 |
| 3 | Imports and Package Loading | compile-error | `MoonBitVM()` 未定义 |
| 4 | Runtime Modules | compile-error | `@eval/async.module()` 未定义 |
| 5 | Runtime Modules（async 示例） | compile-error | `inspect(...)` 解析失败 |

共 5 块：**0 通过 / 5 失败**，全部归因为"依赖 eval 库自身 API"。

## 归因分析

所有块的首个错误都指向 **eval 库自身的 API 不在合成环境作用域内**：

- `let vm = MoonBitVM()` → `Cannot infer the type of variable vm`（`MoonBitVM` 未声明）
- `inspect(...)` → parse error（`inspect` 是 eval 提供的辅助函数）

这是**依赖缺失**，而非库本身的功能缺陷：MoonProof 的最小合成包只引入标准库，未注入 eval 包，因此这些示例天然无法编译。

## 方法论结论

MoonProof 当前的最小合成包只依赖标准库，**无法验证依赖第三方库的示例**。
因此对第三方库 README 的审计结果应解读为：

> "该示例在无该库依赖的干净环境下不可复现"，**不判定为库的功能缺陷**。

这仍然有价值——它把"示例能否被读者直接复制运行"这个问题显式化了：一份依赖自身 API 的 README 示例，在未先 `moon add` 该库、也未包含完整 `import` 时，是不可直接运行的。

## 对 MoonProof 的启示（可完善方向）

为把第三方库审计从"归因缺依赖"推进到"区分真失效"，可扩展**额外依赖注入**：

- CLI 支持 `--dep <package>`，合成包时对目标库执行 `moon add` 并保留示例中的 import；
- 使第三方库 README 的示例在注入依赖后真实编译，从而区分"缺依赖"（v1 已能识别）与"真失效"（依赖注入后仍失败，这才是库或文档的真实 bug）。

这是 v1 之后的自然演进方向，也是本报告的意义所在：它先确认了工具的扫描与归因能力，再暴露出依赖注入这一真实边界。

## 给生态作者的建议

第三方库作者可在 README 提供**含 `moon add` 与完整 `import` 的可复现示例**，或采用 MoonBit 官方的标注驱动文档测试（`mbt check` / `.mbt.md`），让示例随 CI 持续验证，避免读者照抄即卡住。
