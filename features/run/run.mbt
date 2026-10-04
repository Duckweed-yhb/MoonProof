///|
/// features/run — 编排整个验证流程
///
/// scan → extract → synth → 隔离工作区落盘 → moon check/test → 归因 → report。
/// 每个代码块在独立子目录验证，互不干扰。
///
/// 语义：
///   no-check   跳过
///   compile    期望 moon check 通过；失败则归因
///   run        期望 moon test 通过（合成包 is_main=true）
///   should-fail  期望 moon check 失败；若通过说明文档标注失效

///|
/// 一次验证的运行选项
pub struct RunOptions {
  timeout_ms : Int
  /// 验证文档代码块用的后端（传给 moon check/test `--target`）；空串表示不指定
  target : String
}

///|
/// 默认选项：单块编译超时 60s。
pub fn default_options() -> RunOptions {
  { timeout_ms: 60000, target: "" }
}

///|
/// 显式指定超时构造选项（跨包用）。
pub fn make_options(timeout_ms : Int) -> RunOptions {
  { timeout_ms: timeout_ms, target: "" }
}

///|
/// 显式指定超时与后端构造选项（跨包用）。
pub fn make_options_with_target(timeout_ms : Int, target : String) -> RunOptions {
  { timeout_ms, target }
}

///|
/// 运行整个目录的文档验证，返回每份文档的报告。
pub fn run_docs(root : String, opts : RunOptions) -> Result[Array[@report.DocReport], String] {
  let paths = @scan.scan_docs(root)
  let ws = match @workspace.create() {
    Ok(w) => w
    Err(_) => return Err("cannot create isolation workspace")
  }
  let mut counter = 0
  let reports : Array[@report.DocReport] = []
  for p in paths {
    let text = @fs.read_text(p)
    let res = @markdown.extract(text, p)
    let blocks : Array[@report.BlockResult] = []
    for b in res.blocks {
      blocks.push(verify_block(ws, b, p, counter, opts.timeout_ms, opts.target))
      counter = counter + 1
    }
    reports.push(@report.make_report(p, blocks))
  }
  ignore(@workspace.destroy(ws))
  Ok(reports)
}

///|
/// 验证单个代码块。
fn verify_block(
  ws : @workspace.Workspace,
  block : @markdown.CodeBlock,
  doc_path : String,
  index : Int,
  timeout_ms : Int,
  target : String
) -> @report.BlockResult {
  let kind = block.kind.name()
  let start = block.start_line
  if kind == "no-check" {
    return @report.make_block_result(doc_path, start, kind, "skip", "", "", "")
  }
  let sr = @synth.synth_block(block, index, doc_path)
  let dir = match @workspace.alloc(ws, sr.name) {
    Ok(d) => d
    Err(_) => return @report.make_block_result(doc_path, start, kind, "fail", "", "workspace alloc failed", "")
  }
  for f in sr.files {
    if !write_file(dir, f.path, f.content) {
      return @report.make_block_result(doc_path, start, kind, "fail", "", "write failed: " + f.path, "")
    }
  }
  let out = if kind == "run" {
    @toolchain.moon_run(dir, timeout_ms, target)
  } else {
    @toolchain.moon_check(dir, timeout_ms, target)
  }
  match out {
    Ok(o) =>
      if kind == "should-fail" {
        if o.exit_code == 0 {
          @report.make_block_result(doc_path, start, kind, "fail", "", "expected to fail but compiled ok", "")
        } else {
          @report.make_block_result(doc_path, start, kind, "pass", "", "", "")
        }
      } else if o.exit_code == 0 {
        @report.make_block_result(doc_path, start, kind, "pass", "", "", "")
      } else {
        let verdict = @classify.classify(o.stdout, o.stderr).label()
        @report.make_block_result(
          doc_path,
          start,
          kind,
          "fail",
          verdict,
          short(o.stderr),
          @classify.suggestion_for_label(verdict),
        )
      }
    Err(e) =>
      @report.make_block_result(doc_path, start, kind, "fail", "", short(e), "")
  }
}

///|
/// 把合成文件写入隔离工作区（自动创建父目录）。
fn write_file(dir : String, rel : String, content : String) -> Bool {
  let idx = last_slash_index(rel)
  if idx >= 0 {
    let parent = dir + "/" + rel[0:idx].to_owned()
    if !@fs.mkdir_all(parent) {
      return false
    }
  }
  @fs.write_text(dir + "/" + rel, content)
}

///|
/// 最后一个 '/' 的下标；没有则返回 -1。
fn last_slash_index(s : String) -> Int {
  let mut idx = -1
  let mut i = 0
  for c in s {
    if c == '/' {
      idx = i
    }
    i = i + 1
  }
  idx
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
