# MoonProof

> **MoonBit 文档与教程示例的持续验证框架**
>
> 把文档、教程、源文件注释里的 MoonBit 代码块抽出来，在隔离环境中真实编译与运行，回答一个问题：
> **"我们文档里的例子还都对吗？"**

MoonProof 是一个 **库 + CLI**。MoonBit 工具链迭代快，文档里的示例会不断腐坏——学习者照着敲得到编译错误然后卡住，而写文档的人并不知道哪些例子已经失效。MoonProof 让示例像代码一样被 **CI 持续验证**。

MoonBit 官方已提供**标注驱动**的文档测试：doc comments 里的 `mbt check` 块、以及 literate `.mbt.md` 文件（`mbt check` / `mbt nocheck`），都由 `moon check` / `moon test` 自动验证——但**仅在文档作者主动采用这些标注时生效**。MoonProof 与官方机制**互补**，专门解决**未被标注的既有文档**：

- 直接扫描**任意 `.md`**（README、教程、历史文档）里的普通 ```moonbit``` 块——官方对这类块明确"仅展示、不编译测试"；
- 用**代码块信息串**（`run` / `no-check` / `should-fail`）声明期望，容忍片段性示例，不必改写原文档；
- 失败给出**归因分类 + 修复建议**（api-changed / missing-dependency / toolchain-mismatch / …）；
- 支持**批量生态审计**：已对官方错误码 572 项、官方教程 38 块产出失效清单（见 `docs/`）。

一句话：官方机制回答"**标注过的示例**还对不对"，MoonProof 回答"**我仓库里已有的文档**哪些例子已经失效"。

- 许可证：MIT
- 主要语言：MoonBit

---

## 快速开始

```bash
moon run --target native cmd/moonproof -- .
moon run --target native cmd/moonproof -- ./docs --verbose   # 失败块附带具体编译错误，便于定位
moon run --target native cmd/moonproof -- --errorcodes <error_codes 根目录>  # 官方错误码一致性验证
moon run --target native cmd/moonproof -- --errorcodes <error_codes 根目录> --out report.json  # 同时导出 JSON 清单
moon run --target native cmd/moonproof -- . --out report.json   # 文档验证结果导出 JSON
moon run --target native cmd/moonproof -- . --target wasm        # 指定验证后端（wasm/js/native）
```

> 注意：`cmd/moonproof` 是 native-only 的 CLI。**`moon run` 必须带 `--target native`**，否则 moon 默认选 wasm 后端会报 "does not support target backend 'wasm'"。

上面的命令会扫描当前目录下的 `.md` 文档，把每个 ```moonbit 代码块抽出来、在隔离工作区里真实编译（`run` 标注则真正运行），并输出每块的结果与失败归因。加 `--verbose`（或 `-v`）时，每个失败块会缩进输出诊断详情。

下面这个代码块由 MoonProof 在 CI 里**自举验证**（dogfooding）：

```moonbit
fn greet(name : String) -> String {
  "hello, " + name
}
```

## 错误码一致性验证

MoonProof 还能验证 MoonBit 官方错误码示例。官方 `error_codes` 目录里，每个错误码有 `NNNN_error`（故意写错以触发该错误码）与 `NNNN_fixed`（修复版）两个独立小项目。`--errorcodes` 对每个项目真实 `moon check`，断言：

- `NNNN_error` **必须编译失败**（触发该错误码）
- `NNNN_fixed` **必须编译通过**

输出逐码结果与"脱节清单"——即 `error` 不再触发、或 `fixed` 编译失败的错误码。它回答一个问题：**官方错误码示例与当前工具链还一致吗？** 工具链演进会让老错误码示例失效，这份清单可反馈给官方文档仓库修复，保持错误码文档与现实的同步。

加 `--out <json 路径>` 可把完整结果（含逐码 `detail`）导出为 JSON 清单，供 CI 或后续处理消费。一份基于全量 286 个错误码（572 个示例项目）的真实验证报告见 [`docs/error-codes-report.md`](docs/error-codes-report.md)。

```bash
moon run --target native cmd/moonproof -- --errorcodes <error_codes 根目录>
```

### 代码块标注

文档里大量片段是片段性的——只展示语法、故意写错来演示报错、依赖上一段上下文。因此默认行为不是"必须能编译"，而是通过**代码块信息串标注**显式声明期望：

| 标注 | 行为 |
|---|---|
| ` ```moonbit ` | **默认：编译验证**（期望通过） |
| ` ```moonbit run ` | 编译 + 运行验证（`pkgtype executable`，真正执行 main） |
| ` ```moonbit no-check ` | 跳过，不参与验证 |
| ` ```moonbit should-fail ` | **期望编译失败**（用于演示报错） |

---

## 架构

```
cmd/moonproof              CLI 入口：参数解析与分发（仅 native）
  │
features/                  应用层
  ├── scan                扫描目录、筛选 .md / .mbt
  ├── run                 编排：抽取 → 合成 → 执行 → 归因 → 报告
  ├── errorcodes          官方错误码一致性验证（error 断言失败 / fixed 断言通过）
  └── report              结果数据结构与文本渲染
  │
extract/                   抽取层（纯计算，全后端可移植）
  ├── markdown             Markdown 代码块抽取 + 信息串解析
  └── doccomment          .mbt 文档注释抽取
  │
synth/                     合成层（纯计算）
  └── package             代码块 → 最小可编译包 + 行号映射表
  │
diagnose/                  归因层（纯计算，全后端可移植）
  └── classify            编译输出 → 失败类别
  │
exec/                      执行层（仅 native，含 C FFI）
  ├── workspace           一次性隔离工作区（生命周期 / 配额 / 清理）
  └── toolchain           调起 moon check / test / run，捕获输出，超时控制
  │
platform/                  平台层（仅 native，含 C FFI）
  ├── proc                子进程执行 + 输出捕获 + 超时
  └── fs                  目录遍历、UTF-8 读写、删除保护
```

**分层纪律**：`extract/`、`synth/`、`diagnose/`、`features/report` 是纯计算，**不 import 任何 C FFI 包**，因此可在 `wasm` / `wasm-gc` / `js` / `native` 四后端编译与测试。边界用各 `moon.pkg` 的 `supported_targets` 声明、由工具链在构建期强制。执行与平台层只声明 `native`。

**路径编码限制**：`platform/fs` 与 `platform/proc` 在 **Windows 上完整支持非 ASCII（含中文）路径**（宽字符 API）；非 Windows 平台（Linux/macOS）路径按 ASCII 处理、非 ASCII 字符会被替换为 `?`——因此含中文路径的仓库在非 Windows 上不可复现（v1 限制）。

**失败归因**：编译失败被归因为可行动的类别，帮助文档作者判断"例子为什么失效"：
- `compile-error`：语法 / 类型等普通编译错误
- `api-changed`：用了不存在的 API（更可能是工具链演进导致的 API 变更）
- `missing-dependency`：import 的包 / 模块不存在
- `toolchain-mismatch`：工具链 / 后端不兼容
- `missing-main`：Run 标注但代码块缺 main 入口

---

## 测试与自举

- 单元测试：`moon test --target native`（84 用例）
- 纯计算层可移植：`moon test --target wasm`（38 用例，同样覆盖 wasm-gc / js）
- 端到端样例：`examples/sample.md` 覆盖 compile / run / no-check / should-fail 四种标注
- **自举（dogfooding）**：CI 里用 MoonProof 自己验证本仓库 README 与示例文档，任一示例腐坏 → CI 红灯

CI（`.github/workflows/ci.yml`）在 Linux / Windows 双平台跑：build + test（native）、纯计算层 wasm/wasm-gc/js 可移植测试、自举验证。

---

## 来源与许可证

本项目许可证为 **MIT**。

`platform/proc`、`platform/fs`、`exec/workspace` 三个模块复用于作者此前的 MoonHive 项目
（<https://github.com/Duckweed-yhb/moon-hive>，MIT 许可证），仅修改包名以适配本模块，其余为 MoonProof 原创实现。
`extract`、`synth`、`diagnose`、`features` 各层均为原创，未照搬第三方代码。

---

## 目录

```
MoonProof/
├── cmd/moonproof/        CLI 入口
├── extract/              Markdown / 文档注释代码块抽取
├── synth/               代码块合成最小包
├── diagnose/            失败归因分类
├── features/            scan / run / errorcodes / report
├── exec/                隔离工作区 + 工具链执行
├── platform/            子进程 / 文件系统（C FFI）
├── examples/sample.md   端到端样例文档
├── docs/                真实验证报告（error-codes-report / tutorial-audit-report）
├── .github/workflows/    CI
├── moon.mod
└── README.md
```
