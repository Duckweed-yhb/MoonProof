# MoonProof

> **MoonBit 文档与教程示例的持续验证框架**
>
> 把文档、教程、源文件注释里的 MoonBit 代码块抽出来，在隔离环境中真实编译与运行，回答一个问题：
> **"我们文档里的例子还都对吗？"**

MoonProof 是一个 **库 + CLI**。MoonBit 工具链迭代快，文档里的示例会不断腐坏——学习者照着敲得到编译错误然后卡住，而写文档的人并不知道哪些例子已经失效。MoonProof 让示例像代码一样被 **CI 持续验证**。

对比三个成熟生态都有的机制：Rust 有 `rustdoc --test`、Python 有 `doctest`、Go 有 `go test` Example——**MoonBit 目前没有**，这正是 MoonProof 补的生态位。

- 许可证：MIT
- 主要语言：MoonBit

---

## 快速开始

```bash
moon run cmd/moonproof -- .
```

上面的命令会扫描当前目录下的 `.md` 文档，把每个 ```moonbit 代码块抽出来、在隔离工作区里真实编译（`run` 标注则真正运行），并输出每块的结果与失败归因。

下面这个代码块由 MoonProof 在 CI 里**自举验证**（dogfooding）：

```moonbit
fn greet(name : String) -> String {
  "hello, " + name
}
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

**失败归因**：编译失败被归因为可行动的类别，帮助文档作者判断"例子为什么失效"：
- `compile-error`：语法 / 类型等普通编译错误
- `api-changed`：用了不存在的 API（更可能是工具链演进导致的 API 变更）
- `missing-dependency`：import 的包 / 模块不存在
- `toolchain-mismatch`：工具链 / 后端不兼容
- `missing-main`：Run 标注但代码块缺 main 入口

---

## 测试与自举

- 单元测试：`moon test --target native`（52 用例）
- 纯计算层可移植：`moon test --target wasm`（35 用例，同样覆盖 wasm-gc / js）
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
├── features/            scan / run / report
├── exec/                隔离工作区 + 工具链执行
├── platform/            子进程 / 文件系统（C FFI）
├── examples/sample.md   端到端样例文档
├── .github/workflows/    CI
├── moon.mod
└── README.md
```
