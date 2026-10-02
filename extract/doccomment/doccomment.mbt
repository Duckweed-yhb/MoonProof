///|
/// extract/doccomment — .mbt 源文件文档注释（///）代码块抽取
///
/// 从 .mbt 源文本中收集文档注释行（`///` / `///|`），去掉注释前缀后，
/// 复用 extract/markdown 的行级状态机抽取 moonbit 代码块，并把行号
/// 映射回 .mbt 源文件的真实行号。
///
/// 行号语义：返回的 CodeBlock.start_line / end_line 是 **.mbt 原文件
/// 的 1-based 行号**，供 synth 层直接使用。

///|
/// 从 .mbt 源文本抽取文档注释里的 moonbit 代码块。
pub fn extract_doccomment(source : String, path : String) -> @markdown.ExtractResult {
  // 规范化换行（全局替换，core 的 replace 只替换首个匹配）
  let norm = replace_all(replace_all(source, "\r\n", "\n"), "\r", "\n")
  let all_lines : Array[String] = norm.split("\n").map(fn(v) { v.to_owned() }).to_array()

  // 收集文档注释行，去前缀；同时记录每行对应的源文件行号
  let comment_lines : Array[String] = []
  let orig_no : Array[Int] = []
  for i in 0..<all_lines.length() {
    let t = all_lines[i].trim().to_owned()
    if t.has_prefix("///") {
      comment_lines.push(strip_doc_prefix(t))
      orig_no.push(i + 1)
    }
  }

  // 在注释行序列上复用 markdown 的状态机
  let r = @markdown.extract_lines(comment_lines, path)

  // 把行号从 comment_lines 的下标映射回 .mbt 源文件行号
  let remapped : Array[@markdown.CodeBlock] = []
  for b in r.blocks {
    let s = orig_no[b.start_line - 1]
    let e = orig_no[b.end_line - 1]
    remapped.push(@markdown.make_block(s, e, b.code, b.kind))
  }
  @markdown.make_result(path, remapped)
}

///|
/// 去掉文档注释前缀，返回内容行。
/// - `/// 内容` → `内容`
/// - `///| 内容`（块内原样行）→ `内容`
/// - `///内容` → `内容`
fn strip_doc_prefix(t : String) -> String {
  let after = t[3:].to_owned() // 去掉 ///
  if after.has_prefix("|") {
    after[1:].to_owned()
  } else if after.has_prefix(" ") {
    after[1:].to_owned()
  } else {
    after
  }
}

///|
/// 全局替换：把 s 中所有 old 替换为 new（split + join）。
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

test "从文档注释抽取一个 moonbit 代码块" {
  let src = "///|\n/// 示例：\n/// ```moonbit\n/// let x = 1\n/// ```\nfn main() { }\n"
  let r = extract_doccomment(src, "a.mbt")
  assert_eq(r.blocks.length(), 1)
  assert_eq(r.blocks[0].code, "let x = 1")
  assert_eq(r.blocks[0].kind.name(), "compile")
}

test "行号映射回 .mbt 原文件行号" {
  // 第 1 行 fn 定义，第 2-6 行是文档注释，围栏在第 3 行
  let src = "fn main() { }\n///|\n/// 示例\n/// ```moonbit\n/// let a = 1\n/// ```\n"
  let r = extract_doccomment(src, "b.mbt")
  assert_eq(r.blocks.length(), 1)
  assert_eq(r.blocks[0].start_line, 4) // ```moonbit 在 .mbt 的第 4 行
  assert_eq(r.blocks[0].end_line, 6)  // 关闭 ``` 在第 6 行
}

test "run 标注在文档注释中也生效" {
  let src = "/// ```moonbit run\n/// println(\"hi\")\n/// ```\n"
  let r = extract_doccomment(src, "c.mbt")
  assert_eq(r.blocks.length(), 1)
  assert_eq(r.blocks[0].kind.name(), "run")
}

test "非文档注释行被忽略" {
  // 普通 // 注释、代码、空行都不是 /// 文档注释
  let src = "// 普通注释\nfn main() { }\n\n```moonbit\nlet z = 0\n```\n"
  let r = extract_doccomment(src, "d.mbt")
  assert_eq(r.blocks.length(), 0)
}

test "无代码块的文档注释返回空" {
  let src = "/// 只是文字说明，没有代码块\n/// 第二行\n"
  let r = extract_doccomment(src, "e.mbt")
  assert_eq(r.blocks.length(), 0)
}

test "多段文档注释的多个代码块" {
  let src = "/// ```moonbit\n/// let a = 1\n/// ```\nfn f1() {}\n/// ```moonbit\n/// let b = 2\n/// ```\nfn f2() {}\n"
  let r = extract_doccomment(src, "f.mbt")
  assert_eq(r.blocks.length(), 2)
  assert_eq(r.blocks[0].code, "let a = 1")
  assert_eq(r.blocks[1].code, "let b = 2")
}

test "CRLF 换行被规范化且行号正确" {
  let src = "/// ```moonbit\r\n/// let a = 1\r\n/// ```\r\n"
  let r = extract_doccomment(src, "g.mbt")
  assert_eq(r.blocks.length(), 1)
  assert_eq(r.blocks[0].code, "let a = 1")
  assert_eq(r.blocks[0].start_line, 1)
  assert_eq(r.blocks[0].end_line, 3)
}
