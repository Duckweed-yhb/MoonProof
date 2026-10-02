///|
/// synth/package — 代码块 → 最小可编译包 + 行号映射表
///
/// 为每个需验证的代码块合成一个独立最小模块。结构：
///   <name>/
///     moon.mod
///     main/moon.pkg
///     main/main.mbt   （代码块原样）
///
/// 行号映射：main.mbt 第 k 行 ↔ 原文档 (block.start_line + k) 行。
/// 因此 line_map[i] = 原文档行号，其中 i 是 main.mbt 的 0-based 行。

///|
/// 一个待写出的合成文件
pub struct SynthFile {
  /// 相对模块根的路径，如 "main/main.mbt"
  path : String
  content : String
}

///|
/// 一个代码块合成后的最小包
pub struct SynthResult {
  /// 模块名（唯一，如 moonproof_block_0001）
  name : String
  /// 是否为可运行包（Run 标注 → is_main）
  is_run : Bool
  /// 待写出的文件（相对模块根）
  files : Array[SynthFile]
  /// 行号映射表：line_map[i] = 原文档行号（i 为合成 main.mbt 的 0-based 行）
  line_map : Array[Int]
  /// 来源文档路径
  doc_path : String
}

///|
/// 为第 index 个代码块合成最小包。
pub fn synth_block(block : @markdown.CodeBlock, index : Int, doc_path : String) -> SynthResult {
  let name = "moonproof_block_" + pad(index, 4)
  let is_run = block.kind.name() == "run"
  let moon_mod = "name = \"Duckweed/\{name}\"\nversion = \"0.1.0\"\ndescription = \"MoonProof synthesized block\"\n"
  let moon_pkg = if is_run {
    "is_main = true\n"
  } else {
    "is_main = false\n"
  }
  let main_mbt = block.code
  let files = [
    { path: "moon.mod", content: moon_mod },
    { path: "main/moon.pkg", content: moon_pkg },
    { path: "main/main.mbt", content: main_mbt },
  ]
  // 行号映射：code 第 (i+1) 行 ↔ 文档 (start_line + i + 1) 行
  let code_lines = block.code.split("\n").to_array()
  let line_map : Array[Int] = []
  for i in 0..<code_lines.length() {
    line_map.push(block.start_line + i + 1)
  }
  { name, is_run, files, line_map, doc_path }
}

///|
/// 整数补零到指定宽度。
fn pad(n : Int, width : Int) -> String {
  let s = n.to_string()
  let b = StringBuilder()
  let zeros = width - s.length()
  if zeros < 0 {
    return s
  }
  for _ in 0..<zeros {
    b.write_string("0")
  }
  b.write_string(s)
  b.to_string()
}

test "合成包包含 moon.mod / main.moon.pkg / main.mbt，内容为代码块" {
  let block = @markdown.make_block(3, 5, "let x = 1", @markdown.compile_kind())
  let r = synth_block(block, 0, "a.md")
  assert_eq(r.name, "moonproof_block_0000")
  assert_eq(r.is_run, false)
  assert_eq(r.files.length(), 3)
  // main.mbt 内容即代码块
  assert_eq(r.files[2].path, "main/main.mbt")
  assert_eq(r.files[2].content, "let x = 1")
  // moon.pkg 为普通包
  assert_eq(r.files[1].content, "is_main = false\n")
}

test "行号映射：code 第 k 行映射到 start_line + k" {
  let block = @markdown.make_block(10, 14, "let a = 1\nlet b = 2\nlet c = 3", @markdown.compile_kind())
  let r = synth_block(block, 1, "b.md")
  assert_eq(r.line_map.length(), 3)
  assert_eq(r.line_map[0], 11)
  assert_eq(r.line_map[1], 12)
  assert_eq(r.line_map[2], 13)
}

test "Run 标注 → is_main 可运行包" {
  let block = @markdown.make_block(1, 5, "fn main() { println(\"hi\") }", @markdown.run_kind())
  let r = synth_block(block, 2, "c.md")
  assert_eq(r.is_run, true)
  assert_eq(r.files[1].content, "is_main = true\n")
}

test "模块名带序号补零且唯一" {
  let b = @markdown.make_block(1, 2, "x", @markdown.compile_kind())
  let r9 = synth_block(b, 9, "d.md")
  let r123 = synth_block(b, 123, "d.md")
  assert_eq(r9.name, "moonproof_block_0009")
  assert_eq(r123.name, "moonproof_block_0123")
}

test "doc_path 被透传" {
  let b = @markdown.make_block(1, 2, "x", @markdown.compile_kind())
  let r = synth_block(b, 0, "docs/tutorial.md")
  assert_eq(r.doc_path, "docs/tutorial.md")
}
