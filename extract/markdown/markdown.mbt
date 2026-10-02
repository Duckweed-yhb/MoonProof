///|
/// extract/markdown — Markdown 代码块抽取与信息串标注解析
///
/// 从 Markdown 文本中抽取 fenced code block，只关心 moonbit 代码块，
/// 并解析信息串（info string）里的标注，决定该块如何参与验证。
///
/// 标注约定（V1）：
///   ```moonbit            → Compile（默认：编译验证，期望通过）
///   ```moonbit run        → Run（编译 + 运行验证）
///   ```moonbit no-check   → NoCheck（跳过，不参与验证）
///   ```moonbit should-fail→ ShouldFail（期望编译失败，用于演示报错）
///
/// 行号语义：start_line / end_line 为源文档 1-based 行号，
/// 供 synth 层做"合成包行号 ↔ 原文档行号"映射。

///|
/// 代码块验证类型
pub enum Kind {
  Compile
  Run
  NoCheck
  ShouldFail
}

///|
/// 类型对应的标注名（也用于测试与报告）
pub fn Kind::name(self : Kind) -> String {
  match self {
    Compile => "compile"
    Run => "run"
    NoCheck => "no-check"
    ShouldFail => "should-fail"
  }
}

///|
/// 一个被抽取的 moonbit 代码块
pub struct CodeBlock {
  start_line : Int
  end_line : Int
  /// 代码块内容（不含围栏），多行以 \n 连接
  code : String
  kind : Kind
}

///|
/// 一个文档的抽取结果
pub struct ExtractResult {
  /// 文档路径（原样透传，用于报告与行号回填）
  path : String
  blocks : Array[CodeBlock]
}

///|
/// 构造一个代码块（供跨包复用，如 doccomment 做行号重映射）。
pub fn make_block(start_line : Int, end_line : Int, code : String, kind : Kind) -> CodeBlock {
  { start_line, end_line, code, kind }
}

///|
/// 构造抽取结果（供跨包复用）。
pub fn make_result(path : String, blocks : Array[CodeBlock]) -> ExtractResult {
  { path, blocks }
}

///|
/// 从 Markdown 文本抽取全部 moonbit 代码块。
pub fn extract(text : String, path : String) -> ExtractResult {
  // 规范化换行：Markdown 常为 CRLF，统一为 LF 便于行号与内容稳定。
  // 注意 core 的 String::replace 只替换首个匹配，这里用 split+join 做全局替换。
  let norm = replace_all(replace_all(text, "\r\n", "\n"), "\r", "\n")
  let lines : Array[String] = norm.split("\n").map(fn(v) { v.to_owned() }).to_array()
  extract_lines(lines, path)
}

///|
/// 对行数组抽取全部 moonbit 代码块。
///
/// 供本包的 extract（Markdown）与 extract/doccomment 复用：只要把
/// 目标文本按行拆开即可，行号以数组下标为基准（1-based），由调用方
/// 决定如何映射回真实源文件行号。
pub fn extract_lines(lines : Array[String], path : String) -> ExtractResult {
  let blocks : Array[CodeBlock] = []
  let mut i = 0
  let n = lines.length()
  while i < n {
    let line = lines[i]
    if is_fence(line) {
      let info = fence_info(line)
      if is_moonbit_fence(info) {
        // 收集 moonbit 块直到配对的关闭围栏
        let start_line = i + 1
        let kind = parse_kind(info)
        let mut j = i + 1
        let code_lines : Array[String] = []
        let mut closed = false
        while j < n {
          if is_fence(lines[j]) {
            let end_line = j + 1
            blocks.push({ start_line, end_line, code: join_lines(code_lines), kind })
            closed = true
            j += 1
            break
          } else {
            code_lines.push(lines[j])
            j += 1
          }
        }
        if !closed {
          // 未闭合的块：取到文末
          let end_line = n
          blocks.push({ start_line, end_line, code: join_lines(code_lines), kind })
        }
        i = j
      } else {
        // 非 moonbit 围栏：跳过整个块到其关闭围栏，不收集
        let mut j = i + 1
        while j < n {
          if is_fence(lines[j]) {
            j += 1
            break
          }
          j += 1
        }
        i = j
      }
    } else {
      i += 1
    }
  }
  { path, blocks }
}

///|
/// 全局替换：把 s 中所有 old 替换为 new（split + join）。
/// core 的 String::replace 只替换首个匹配，不能用。
fn replace_all(s : String, old : String, new : String) -> String {
  let parts = s.split(old).to_array()
  let b = StringBuilder()
  let mut first = true
  for p in parts {
    if !first {
      b.write_string(new)
    }
    b.write_string(p.to_owned())
    first = false
  }
  b.to_string()
}

///|
/// 判断一行是否为围栏（``` 开头）。
fn is_fence(line : String) -> Bool {
  line.trim().to_owned().has_prefix("```")
}

///|
/// 取围栏行的信息串（去掉前导 ``` 与首尾空白）。
/// 例如 "```moonbit run" → "moonbit run"。
fn fence_info(line : String) -> String {
  let t = line.trim().to_owned()
  t[3:].to_owned()
}

///|
/// 信息串是否指向 moonbit 代码块（第一个 token == "moonbit"）。
fn is_moonbit_fence(info : String) -> Bool {
  let t = info.trim().to_owned()
  t == "moonbit" || t.has_prefix("moonbit ")
}

///|
/// 解析信息串里的标注，返回验证类型。
/// 默认 Compile；遇到 run / no-check / should-fail 时覆盖。
fn parse_kind(info : String) -> Kind {
  let mut kind : Kind = Compile
  for token in info.split(" ") {
    match token.trim().to_owned() {
      "run" => kind = Run
      "no-check" => kind = NoCheck
      "should-fail" => kind = ShouldFail
      _ => ()
    }
  }
  kind
}

///|
/// 用 \n 连接代码行。
fn join_lines(lines : Array[String]) -> String {
  let b = StringBuilder()
  let mut first = true
  for l in lines {
    if !first {
      b.write_string("\n")
    }
    b.write_string(l)
    first = false
  }
  b.to_string()
}

test "抽取一个默认 moonbit 块，类型为 Compile" {
  let doc = "# 标题\n\n```moonbit\nlet x = 1\n```\n"
  let r = extract(doc, "a.md")
  assert_eq(r.blocks.length(), 1)
  assert_eq(r.blocks[0].kind.name(), "compile")
  assert_eq(r.blocks[0].code, "let x = 1")
}

test "run 标注块解析为 Run" {
  let doc = "```moonbit run\nprintln(\"hi\")\n```\n"
  let r = extract(doc, "b.md")
  assert_eq(r.blocks.length(), 1)
  assert_eq(r.blocks[0].kind.name(), "run")
}

test "no-check 与 should-fail 标注" {
  let doc = "```moonbit no-check\n// 仅展示\n```\n\n```moonbit should-fail\nlet : Int = \"oops\"\n```\n"
  let r = extract(doc, "c.md")
  assert_eq(r.blocks.length(), 2)
  assert_eq(r.blocks[0].kind.name(), "no-check")
  assert_eq(r.blocks[1].kind.name(), "should-fail")
}

test "非 moonbit 围栏（python）被跳过" {
  let doc = "```python\nprint(1)\n```\n\n```moonbit\nlet y = 2\n```\n"
  let r = extract(doc, "d.md")
  assert_eq(r.blocks.length(), 1)
  assert_eq(r.blocks[0].code, "let y = 2")
}

test "行号正确（1-based 围栏所在行）" {
  let doc = "第1行\n\n```moonbit\nlet a = 1\n```\n尾部\n"
  let r = extract(doc, "e.md")
  assert_eq(r.blocks.length(), 1)
  assert_eq(r.blocks[0].start_line, 3)
  assert_eq(r.blocks[0].end_line, 5)
}

test "多个 moonbit 块都被抽取" {
  let doc = "```moonbit\nlet a = 1\n```\n```moonbit\nlet b = 2\n```\n"
  let r = extract(doc, "f.md")
  assert_eq(r.blocks.length(), 2)
  assert_eq(r.blocks[0].code, "let a = 1")
  assert_eq(r.blocks[1].code, "let b = 2")
}

test "无围栏的文档返回空结果" {
  let doc = "纯文本，没有任何代码块\n"
  let r = extract(doc, "g.md")
  assert_eq(r.blocks.length(), 0)
}

test "CRLF 换行被规范化" {
  let doc = "```moonbit\r\nlet a = 1\r\n```\r\n"
  let r = extract(doc, "h.md")
  assert_eq(r.blocks.length(), 1)
  assert_eq(r.blocks[0].code, "let a = 1")
  assert_eq(r.blocks[0].start_line, 1)
  assert_eq(r.blocks[0].end_line, 3)
}

test "path 被原样透传" {
  let r = extract("```moonbit\nx\n```\n", "docs/guide.md")
  assert_eq(r.path, "docs/guide.md")
}
