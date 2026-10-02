///|
/// diagnose/classify — 编译输出归因分类
///
/// 纯计算层：给定工具链输出（stdout + stderr），把一次**编译失败**归因为
/// 可行动的类别，帮助文档作者判断"例子为什么失效"。分类只处理失败情形；
/// 通过情形由 run 编排层直接判定为 Pass。
///
/// 类别语义（对文档作者最有区分度的几类）：
///   CompileError       语法 / 类型等普通编译错误（例子本身写错）
///   ApiChanged         用了不存在的 API（has no method / unresolved identifier …）
///                        → 更可能是工具链演进导致的 API 变更，不是例子写错
///   MissingDependency  import 的包 / 模块不存在
///   ToolchainMismatch  工具链 / 后端不兼容（如 wasm 不支持 FFI）
///   MissingMain        Run 标注但代码块缺 main 入口
///   Unknown            其它失败
///
/// ⚠️ 特征措辞基于常见 moon 诊断文本，MVP 先按合理默认实现，端到端用真实
///    工具链输出校准（见任务 #8）。

///|
/// 编译失败的归因类别
pub enum Verdict {
  CompileError
  ApiChanged
  MissingDependency
  ToolchainMismatch
  MissingMain
}

///|
/// 类别对应的标签（用于报告）。
pub fn Verdict::label(self : Verdict) -> String {
  match self {
    CompileError => "compile-error"
    ApiChanged => "api-changed"
    MissingDependency => "missing-dependency"
    ToolchainMismatch => "toolchain-mismatch"
    MissingMain => "missing-main"
  }
}

///|
/// 对一次失败的工具链输出做归因。
pub fn classify(stdout : String, stderr : String) -> Verdict {
  let text = (stdout + "\n" + stderr).to_lower()
  if contains_any(text, [
    "incompatible with",
    "does not support target backend",
    "selected backend",
  ]) {
    ToolchainMismatch
  } else if contains_any(text, [
    "cannot find package",
    "package not found",
    "failed to resolve",
    "unable to find",
  ]) {
    MissingDependency
  } else if contains_any(text, [
    "has no main",
    "no main function",
    "does not have a main",
    "no entry function",
  ]) {
    MissingMain
  } else if contains_any(text, [
    "has no method",
    "unresolved identifier",
    "unknown type",
    "has no definition",
    "no field",
    "cannot find type",
  ]) {
    ApiChanged
  } else {
    CompileError
  }
}

///|
/// text 中是否包含任一特征串（小写后匹配）。
fn contains_any(text : String, needles : Array[String]) -> Bool {
  for n in needles {
    if text.contains(n) {
      return true
    }
  }
  false
}

test "语法错误归为 compile-error" {
  let v = classify("", "Error: expected expression")
  assert_eq(v.label(), "compile-error")
}

test "类型错误归为 compile-error（非 API）" {
  let v = classify("", "Error: Type mismatch\n  has type : Int\n  wanted : String")
  assert_eq(v.label(), "compile-error")
}

test "has no method 归为 api-changed" {
  let v = classify("", "Error: type Bytes has no method exact_view")
  assert_eq(v.label(), "api-changed")
}

test "unresolved identifier 归为 api-changed" {
  let v = classify("", "Error: unresolved identifier foo")
  assert_eq(v.label(), "api-changed")
}

test "依赖缺失归为 missing-dependency" {
  let v = classify("", "Error: cannot find package moonbitlang/core/fs")
  assert_eq(v.label(), "missing-dependency")
}

test "后端不兼容归为 toolchain-mismatch" {
  let v = classify("", "Selected backend 'wasm' is incompatible with the dependency graph")
  assert_eq(v.label(), "toolchain-mismatch")
}

test "缺 main 归为 missing-main" {
  let v = classify("", "Error: this package is is_main but has no main function")
  assert_eq(v.label(), "missing-main")
}

test "无特征的非零输出兜底为 compile-error" {
  // 无任何特征 → 默认 compile-error
  let v = classify("", "some cryptic failure message")
  assert_eq(v.label(), "compile-error")
}

test "大小写不敏感" {
  let v = classify("", "Type Bytes has NO METHOD exact_view")
  assert_eq(v.label(), "api-changed")
}

test "stdout 也被检查" {
  let v = classify("unresolved identifier xyz", "")
  assert_eq(v.label(), "api-changed")
}
