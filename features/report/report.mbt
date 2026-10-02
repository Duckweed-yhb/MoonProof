///|
/// features/report — 验证结果的数据结构与渲染
///
/// 纯计算层：定义一次文档验证的块级结果（BlockResult）与文档级汇总
/// （DocReport），并提供文本渲染。run 编排层负责填充这些结构。
///
/// 字段刻意用 String 而非跨包 enum，避免跨包构造限制，降低耦合。

///|
/// 单个代码块的验证结果
pub struct BlockResult {
  path : String
  /// 在源文档中的起始行号（1-based）
  start_line : Int
  /// 标注：compile / run / no-check / should-fail
  kind : String
  /// pass / fail / skip
  status : String
  /// 失败时的归因标签（api-changed 等）；成功或跳过为空串
  verdict : String
  /// 失败时的诊断摘要（stderr 首段）；成功或跳过为空串
  detail : String
}

///|
/// 一份文档的整体验证结果
pub struct DocReport {
  path : String
  total : Int
  passed : Int
  failed : Int
  skipped : Int
  blocks : Array[BlockResult]
}

///|
/// 构造一个块级结果（跨包用）。
pub fn make_block_result(
  path : String,
  start_line : Int,
  kind : String,
  status : String,
  verdict : String,
  detail : String
) -> BlockResult {
  { path, start_line, kind, status, verdict, detail }
}

///|
/// 由块结果现算文档级汇总。
pub fn make_report(path : String, blocks : Array[BlockResult]) -> DocReport {
  let mut total = 0
  let mut passed = 0
  let mut failed = 0
  let mut skipped = 0
  for b in blocks {
    total = total + 1
    if b.status == "pass" {
      passed = passed + 1
    } else if b.status == "skip" {
      skipped = skipped + 1
    } else {
      failed = failed + 1
    }
  }
  { path, total, passed, failed, skipped, blocks }
}

///|
/// 渲染成多行文本报告（每块一行）。
pub fn render_text(r : DocReport) -> String {
  let mut s = ""
  s = s + "== " + r.path + " ==\n"
  for b in r.blocks {
    let mut line = "  " + b.status
    line = line + " [@" + b.start_line.to_string() + "] " + b.kind
    if b.verdict.length() > 0 {
      line = line + " " + b.verdict
    }
    line = line + "\n"
    s = s + line
  }
  s = s + summarize(r) + "\n"
  s
}

///|
/// 单文档汇总行。
pub fn summarize(r : DocReport) -> String {
  "  total=" + r.total.to_string() + " pass=" + r.passed.to_string() + " fail=" +
  r.failed.to_string() + " skip=" + r.skipped.to_string()
}

// ---------- 测试 ----------

test "空文档汇总为零" {
  let r = make_report("a.md", [])
  assert_eq(r.total, 0)
  assert_eq(r.failed, 0)
}

test "汇总正确计数 pass/fail/skip" {
  let b1 = make_block_result("a.md", 3, "compile", "pass", "", "")
  let b2 = make_block_result("a.md", 10, "compile", "fail", "api-changed", "has no method")
  let b3 = make_block_result("a.md", 20, "compile", "skip", "", "")
  let r = make_report("a.md", [b1, b2, b3])
  assert_eq(r.total, 3)
  assert_eq(r.passed, 1)
  assert_eq(r.failed, 1)
  assert_eq(r.skipped, 1)
}

test "渲染包含路径与状态" {
  let b1 = make_block_result("a.md", 3, "compile", "pass", "", "")
  let r = make_report("a.md", [b1])
  let t = render_text(r)
  assert_true(t.contains("a.md"))
  assert_true(t.contains("pass"))
  assert_true(t.contains("total=1"))
}

test "失败块带归因标签" {
  let b1 = make_block_result("a.md", 5, "compile", "fail", "api-changed", "has no method exact_view")
  let r = make_report("a.md", [b1])
  let t = render_text(r)
  assert_true(t.contains("api-changed"))
}
