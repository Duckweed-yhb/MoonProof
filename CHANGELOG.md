# Changelog

本项目所有显著变更都会记录在此文件。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added
- 代码块顶部连续 `import { ... }` 自动迁移到 `moon.pkg`：新版 MoonBit 要求 import 声明放在 `moon.pkg`，迁移后含 import 的第三方库文档示例（配合 `--dep`）可被真实编译验证，不再误报 `compile-error`。
- Cram CLI 冒烟覆盖扩展：`--target wasm` / `--out <json>` / `--dep <pkg>` 用例。
- 单元测试：native 87 → 91，wasm 46 → 50（含 import 迁移 4 例）。

### Changed
- README 补充"第三方库文档审计（`--dep` + import 自动迁移）"用法与测试数同步（91 / 50）。
- 端到端实证：`--dep moonbitlang/x` 下 uuid 文档示例（含 import + `fn main raise`）编译通过。

## [0.1.3] - 2026-10-07

### Changed
- README 同步测试用例数（native 87 / 纯计算层 46），补充 AI 使用说明。
- CLI `--help` 补全 `--target` / `--dep` 选项说明（对齐 README 声明）。
- 工作区 / 临时目录前缀由 `moonhive-*` 统一为 `moonproof-*`（命名整洁）。

## [0.1.2] - 2026-09

### Added
- 文档验证模式 `--out <json>`：导出 JSON 报告数组。
- `--target <wasm|js|native>`：指定验证后端。

### Changed
- README 同步测试用例数、`--out` / `--target` 用法，重新发布 mooncakes。

## [0.1.1] - 2026-09

### Added
- 依赖注入 `--dep <owner/name>`：编译前 `moon add` 注入第三方依赖，支持审计依赖库的文档示例。
- Cram CLI 冒烟测试（scrut 引擎，Linux CI）。
- 第三、四份生态审计报告（官方教程 38 块、第三方库 `oboard/eval` README 可复现性）。

## [0.1.0] - 2026-08

### Added
- MoonProof MVP：扫描 `.md` / `.mbt` → 抽取代码块 → 合成最小包 → 隔离编译/运行 → 归因分类 → 报告。
- 代码块信息串标注：`run` / `no-check` / `should-fail`。
- 失败归因分类器：`compile-error` / `api-changed` / `missing-dependency` / `toolchain-mismatch` / `missing-main`。
- 官方错误码一致性验证（`--errorcodes`，error 断言失败 / fixed 断言通过）。
- 纯计算层（extract/synth/diagnose/features/report）支持 wasm / wasm-gc / js / native 四后端。
- CI：Linux / Windows 双平台构建测试 + 库核心可移植测试 + 自举（dogfooding）。
- MIT 许可证；发布至 mooncakes。

[0.1.3]: https://mooncakes.io/docs/Duckweed/moon-proof@0.1.3
[0.1.2]: https://mooncakes.io/docs/Duckweed/moon-proof@0.1.2
[0.1.1]: https://mooncakes.io/docs/Duckweed/moon-proof@0.1.1
[0.1.0]: https://mooncakes.io/docs/Duckweed/moon-proof@0.1.0
