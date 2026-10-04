///|
/// features/errorcodes — 官方错误码一致性验证
///
/// 见 moon.pkg 顶部说明：对 error_codes 下每个 `NNNN_error` 断言编译失败、
/// `NNNN_fixed` 断言编译通过，输出统计与脱节清单。
///
/// 语义约定：
///   status "pass"  = 断言成立（error 确实失败 / fixed 确实通过）
///   status "fail"  = 断言不成立（error 没触发 / fixed 编译失败 / 复制失败）

///|
/// 验证选项
pub struct EcOptions {
  timeout_ms : Int
}

///|
/// 默认选项：单项目编译超时 60s。
pub fn default_options() -> EcOptions {
  { timeout_ms: 60000 }
}

///|
/// 从 CLI 传入的超时构造选项。
pub fn make_options(timeout_ms : Int) -> EcOptions {
  { timeout_ms: timeout_ms }
}

///|
/// 单个错误码的验证结果
pub struct EcResult {
  /// 项目目录完整路径
  path : String
  /// 错误码（NNNN）
  code : String
  /// error / fixed
  kind : String
  /// pass / fail（断言是否成立）
  status : String
  /// moon check 退出码（-1 表示复制或执行失败）
  exit_code : Int
  /// 失败时的诊断摘要
  detail : String
}

///|
/// 整体验证报告
pub struct EcReport {
  /// 参与验证的项目数（error + fixed）
  total : Int
  error_total : Int
  fixed_total : Int
  /// error 中确实触发失败的数量
  error_triggered : Int
  /// fixed 中确实编译通过的数量
  fixed_passed : Int
  results : Array[EcResult]
}

///|
/// 验证整个 error_codes 根目录。
pub fn verify_errorcodes(root : String, opts : EcOptions) -> Result[EcReport, String] {
  let ws = match @workspace.create() {
    Ok(w) => w
    Err(_) => return Err("cannot create isolation workspace")
  }
  let projects = scan_projects(root)
  let results : Array[EcResult] = []
  let mut error_total = 0
  let mut fixed_total = 0
  let mut error_triggered = 0
  let mut fixed_passed = 0
  for p in projects {
    let dirname = basename(p)
    let kind = if dirname.has_suffix("_error") {
      "error"
    } else {
      "fixed"
    }
    let code = code_of(dirname)
    let work = match @workspace.alloc(ws, dirname) {
      Ok(d) => d
      Err(_) => continue
    }
    if !@fs.copy_tree(p, work) {
      results.push(
        { path: p, code, kind, status: "fail", exit_code: -1, detail: "copy failed" },
      )
      continue
    }
    let out = match @toolchain.moon_check(work, opts.timeout_ms, "") {
      Ok(o) => o
      Err(e) =>
        {
          results.push(
            { path: p, code, kind, status: "fail", exit_code: -1, detail: short(e) },
          )
          continue
        }
    }
    if kind == "error" {
      error_total = error_total + 1
      if out.exit_code != 0 {
        error_triggered = error_triggered + 1
      }
    } else {
      fixed_total = fixed_total + 1
      if out.exit_code == 0 {
        fixed_passed = fixed_passed + 1
      }
    }
    let success = if kind == "error" {
      out.exit_code != 0
    } else {
      out.exit_code == 0
    }
    results.push(
      {
        path: p,
        code,
        kind,
        status: if success {
          "pass"
        } else {
          "fail"
        },
        exit_code: out.exit_code,
        detail: if success {
          ""
        } else {
          short(out.stderr)
        },
      },
    )
  }
  ignore(@workspace.destroy(ws))
  Ok(
    {
      total: results.length(),
      error_total,
      fixed_total,
      error_triggered,
      fixed_passed,
      results,
    },
  )
}

///|
/// 扫描 error_codes 根下所有 `NNNN_error` / `NNNN_fixed` 项目目录。
fn scan_projects(root : String) -> Array[String] {
  let seen : Array[String] = []
  let projects : Array[String] = []
  for f in @fs.list_files(root, "", 2) {
    let rel = f[root.length():].to_owned()
    let first = first_segment(rel)
    if first.length() > 0 && is_error_code_dir(first) && !contains_str(seen, first) {
      seen.push(first)
      projects.push(@proc.join_path(root, first))
    }
  }
  projects
}

///|
/// 目录名是否为 `NNNN_error` / `NNNN_fixed`（前缀全数字）。
fn is_error_code_dir(name : String) -> Bool {
  let has_err = name.has_suffix("_error")
  let has_fix = name.has_suffix("_fixed")
  if !has_err && !has_fix {
    return false
  }
  let n = name.length()
  let num_len = n - 6
  if num_len <= 0 {
    return false
  }
  for i = 0; i < num_len; i = i + 1 {
    let c = name.unsafe_get(i)
    if c.to_int() < '0'.to_int() || c.to_int() > '9'.to_int() {
      return false
    }
  }
  true
}

///|
/// 从 `NNNN_error` / `NNNN_fixed` 中取出错误码 NNNN。
fn code_of(name : String) -> String {
  let n = name.length()
  for i = 0; i < n; i = i + 1 {
    if name.unsafe_get(i) == '_' {
      return name[0:i].to_owned()
    }
  }
  name
}

///|
/// 取路径最后一段（目录名）。
fn basename(p : String) -> String {
  let n = p.length()
  let mut i = n
  while i > 0 {
    let c = p.unsafe_get(i - 1)
    if c == '/' || c == '\\' {
      return p[i:].to_owned()
    }
    i = i - 1
  }
  p
}

///|
/// 取相对路径的第一段目录名（跳过开头的分隔符）。
fn first_segment(rel : String) -> String {
  let n = rel.length()
  let mut start = 0
  while start < n && (rel.unsafe_get(start) == '/' || rel.unsafe_get(start) == '\\') {
    start = start + 1
  }
  let mut i = start
  while i < n {
    let c = rel.unsafe_get(i)
    if c == '/' || c == '\\' {
      return rel[start:i].to_owned()
    }
    i = i + 1
  }
  rel[start:].to_owned()
}

///|
/// 数组是否包含指定字符串
fn contains_str(arr : Array[String], s : String) -> Bool {
  for x in arr {
    if x == s {
      return true
    }
  }
  false
}

///|
/// 截断诊断摘要到 300 字符。
fn short(s : String) -> String {
  if s.length() > 300 {
    s[0:300].to_owned()
  } else {
    s
  }
}

///|
/// 渲染为多行文本报告。
pub fn render_ec(r : EcReport) -> String {
  let mut s = ""
  s = s + "== error_codes 一致性验证 ==\n"
  for x in r.results {
    let line = "  " + x.status + " [" + x.code + "] " + x.kind + " exit=" +
      x.exit_code.to_string()
    s = s + line + "\n"
    if x.detail.length() > 0 {
      let lines = x.detail.split("\n")
      for l in lines {
        s = s + "      " + l.to_owned() + "\n"
      }
    }
  }
  s = s + summarize_ec(r) + "\n"
  s
}

///|
/// 汇总行。
pub fn summarize_ec(r : EcReport) -> String {
  "  total=" + r.total.to_string() + " error=" + r.error_total.to_string() + " (triggered " +
  r.error_triggered.to_string() + ") fixed=" + r.fixed_total.to_string() + " (passed " +
  r.fixed_passed.to_string() + ")"
}

///|
/// 序列化为 JSON 清单（含逐码 detail），供 CI / 官方反馈 / 后续处理消费。
pub fn to_json(r : EcReport) -> String {
  let mut s = "{\"total\":" + r.total.to_string() + ",\"error_total\":" +
    r.error_total.to_string() + ",\"fixed_total\":" + r.fixed_total.to_string() +
    ",\"error_triggered\":" + r.error_triggered.to_string() + ",\"fixed_passed\":" +
    r.fixed_passed.to_string() + ",\"results\":["
  let mut first = true
  for x in r.results {
    if !first {
      s = s + ","
    }
    first = false
    s = s + "{\"code\":\"" + escape_json(x.code) + "\",\"kind\":\"" + escape_json(x.kind) +
      "\",\"status\":\"" + escape_json(x.status) + "\",\"exit_code\":" +
      x.exit_code.to_string() + ",\"detail\":\"" + escape_json(x.detail) + "\"}"
  }
  s + "]}"
}

///|
/// JSON 字符串转义（引号、反斜杠、控制字符）。
fn escape_json(s : String) -> String {
  let mut out = ""
  for c in s {
    if c == '"' {
      out = out + "\\\""
    } else if c == '\\' {
      out = out + "\\\\"
    } else if c == '\n' {
      out = out + "\\n"
    } else if c == '\r' {
      out = out + "\\r"
    } else if c == '\t' {
      out = out + "\\t"
    } else {
      out = out + c.to_string()
    }
  }
  out
}

// ---------- 单元测试 ----------

test "is_error_code_dir 识别 NNNN_error/fixed" {
  assert_true(is_error_code_dir("0001_error"))
  assert_true(is_error_code_dir("0014_fixed"))
  assert_false(is_error_code_dir("0001_foo"))
  assert_false(is_error_code_dir("ab_error"))
  assert_false(is_error_code_dir("_error"))
  assert_false(is_error_code_dir("123_error_extra"))
  assert_true(is_error_code_dir("1_error"))
}

test "code_of 提取错误码" {
  assert_eq(code_of("0001_error"), "0001")
  assert_eq(code_of("0014_fixed"), "0014")
}

test "basename 取路径最后一段" {
  assert_eq(basename("a/b/0001_error"), "0001_error")
  assert_eq(basename("0001_error"), "0001_error")
}

test "first_segment 取相对路径第一段" {
  assert_eq(first_segment("/0001_error/moon.mod.json"), "0001_error")
  assert_eq(first_segment("\\0001_error\\moon.mod.json"), "0001_error")
  assert_eq(first_segment("0001_error/moon.mod.json"), "0001_error")
}

test "scan_projects 只收集 NNNN_error/fixed 目录" {
  let base = @proc.join_path(@proc.temp_dir(), "ec-scan-" + @env.now().to_string())
  ignore(@fs.rm_rf(base))
  ignore(@fs.mkdir_all(base))
  ignore(@fs.mkdir_all(@proc.join_path(base, "0001_error")))
  ignore(@fs.mkdir_all(@proc.join_path(base, "0001_fixed")))
  ignore(@fs.mkdir_all(@proc.join_path(base, "misc")))
  ignore(
    @fs.write_text(@proc.join_path(@proc.join_path(base, "0001_error"), "moon.mod.json"), "{}"),
  )
  ignore(
    @fs.write_text(@proc.join_path(@proc.join_path(base, "0001_fixed"), "moon.mod.json"), "{}"),
  )
  ignore(@fs.write_text(@proc.join_path(@proc.join_path(base, "misc"), "a.mbt"), "x"))
  let projs = scan_projects(base)
  assert_eq(projs.length(), 2)
  ignore(@fs.rm_rf(base))
}

test "escape_json 转义引号反斜杠换行" {
  assert_eq(escape_json("a\"b"), "a\\\"b")
  assert_eq(escape_json("a\\b"), "a\\\\b")
  assert_eq(escape_json("a\nb"), "a\\nb")
  assert_eq(escape_json("plain"), "plain")
}

test "to_json 输出含统计与逐码字段" {
  let r : EcReport = {
    total: 2,
    error_total: 1,
    fixed_total: 1,
    error_triggered: 0,
    fixed_passed: 1,
    results: [
      { path: "/x/0001_error", code: "0001", kind: "error", status: "fail", exit_code: 0, detail: "warn" },
      { path: "/x/0001_fixed", code: "0001", kind: "fixed", status: "pass", exit_code: 0, detail: "" },
    ],
  }
  let j = to_json(r)
  assert_true(j.has_prefix("{\"total\":2"))
  assert_true(j.contains("\"error_triggered\":0"))
  assert_true(j.contains("\"code\":\"0001\""))
  assert_true(j.contains("\"kind\":\"error\""))
  assert_true(j.contains("\"status\":\"fail\""))
  assert_true(j.contains("\"detail\":\"warn\""))
}
