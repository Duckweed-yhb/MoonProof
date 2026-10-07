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
  // 含顶层 fn main 的块也须用可执行包：`fn main` 在库包（moon.pkg 空）中不合法，
  // 否则会导致对本身正确的代码块误报 compile-error。
  // 用行首匹配而非子串 contains，避免代码里字符串/注释含 "fn main" 造成误判。
  let has_main = has_top_level_main(block.code)
  // 提取代码块顶部的 import 声明，迁移到 moon.pkg：新版 MoonBit 要求 import 声明放在
  // moon.pkg，代码文件内写 `import { "pkg" }` 会报 "Invalid import declaration"。
  // 不迁移时，审计含 import 的第三方库文档示例必然误报 compile-error。
  let (imports, body) = split_top_imports(block.code)
  let moon_mod = "name = \"Duckweed/\{name}\"\nversion = \"0.1.0\"\ndescription = \"MoonProof synthesized block\"\n"
  // 可运行块或含 fn main 的块用 pkgtype(kind:"executable") 标记 main 入口（本工具链版本不用 is_main）。
  let pkg_builder = StringBuilder()
  if is_run || has_main {
    pkg_builder.write_string("pkgtype(kind: \"executable\")\n")
  }
  for imp in imports {
    pkg_builder.write_string(imp)
    pkg_builder.write_string("\n")
  }
  let moon_pkg = pkg_builder.to_string()
  let main_mbt = body
  let files = [
    { path: "moon.mod", content: moon_mod },
    { path: "main/moon.pkg", content: moon_pkg },
    { path: "main/main.mbt", content: main_mbt },
  ]
  // 行号映射：body 第 (k+1) 行 ↔ 文档 (start_line + import_count + k + 1) 行。
  // 顶部 import 行已从 body 移出到 moon.pkg，原行号需加 import_count 偏移。
  let code_lines = body.split("\n").to_array()
  let line_map : Array[Int] = []
  let import_count = imports.length()
  for k in 0..<code_lines.length() {
    line_map.push(block.start_line + import_count + k + 1)
  }
  { name, is_run, files, line_map, doc_path }
}

///|
/// 提取代码块顶部连续的 import 声明行，返回 (import 行数组, 剩余代码)。
/// 只处理单行 import（`import "pkg"` 或 `import { "pkg" }`）；跨行 import 不迁移，留原位。
fn split_top_imports(code : String) -> (Array[String], String) {
  // split 返回 Array[StringView]，转成 owned String 供后续 String API 使用
  let lines = code.split("\n").map(fn(v) { v.to_owned() }).to_array()
  let imports : Array[String] = []
  let mut i = 0
  while i < lines.length() && is_import_line(lines[i]) {
    imports.push(lines[i].trim().to_owned())
    i = i + 1
  }
  let b = StringBuilder()
  let mut j = i
  while j < lines.length() {
    if j > i {
      b.write_string("\n")
    }
    b.write_string(lines[j])
    j = j + 1
  }
  (imports, b.to_string())
}

///|
/// 是否单行 import 声明（行首 `import ` 或恰好 `import`）。
fn is_import_line(line : String) -> Bool {
  let t = line.trim().to_owned()
  t == "import" || t.has_prefix("import ")
}

///|
/// 是否含顶层 `fn main`（行首，忽略前导空白）。
fn has_top_level_main(code : String) -> Bool {
  for line in code.split("\n") {
    let t = line.trim().to_owned()
    if t.has_prefix("fn main") {
      return true
    }
  }
  false
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
  // moon.pkg 为普通库包（空内容）
  assert_eq(r.files[1].content, "")
  // moon.mod 无需外部 deps（core 自动可用）
  assert_true(!r.files[0].content.contains("deps"))
}

test "行号映射：code 第 k 行映射到 start_line + k" {
  let block = @markdown.make_block(10, 14, "let a = 1\nlet b = 2\nlet c = 3", @markdown.compile_kind())
  let r = synth_block(block, 1, "b.md")
  assert_eq(r.line_map.length(), 3)
  assert_eq(r.line_map[0], 11)
  assert_eq(r.line_map[1], 12)
  assert_eq(r.line_map[2], 13)
}

test "Run 标注 → 可执行包（pkgtype executable）" {
  let block = @markdown.make_block(1, 5, "fn main() { println(\"hi\") }", @markdown.run_kind())
  let r = synth_block(block, 2, "c.md")
  assert_eq(r.is_run, true)
  assert_eq(r.files[1].content, "pkgtype(kind: \"executable\")\n")
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

test "字符串里的 fn main 不触发可执行包" {
  let b = @markdown.make_block(1, 2, "println(\"fn main\")", @markdown.compile_kind())
  let r = synth_block(b, 0, "x.md")
  // 库包（空内容），不因子串误判为 executable
  assert_eq(r.files[1].content, "")
}

test "顶层 fn main 触发可执行包" {
  let b = @markdown.make_block(1, 2, "fn main() { }", @markdown.compile_kind())
  let r = synth_block(b, 0, "x.md")
  assert_eq(r.files[1].content, "pkgtype(kind: \"executable\")\n")
}

test "带缩进的 fn main 也被识别" {
  let b = @markdown.make_block(1, 2, "  fn main() { }", @markdown.compile_kind())
  let r = synth_block(b, 0, "x.md")
  assert_eq(r.files[1].content, "pkgtype(kind: \"executable\")\n")
}

test "顶部单行 import 迁移到 moon.pkg" {
  let b = @markdown.make_block(1, 3, "import { \"moonbitlang/x/uuid\" }\nfn main raise { }", @markdown.compile_kind())
  let r = synth_block(b, 0, "a.md")
  // import 行进入 moon.pkg，main.mbt 只保留 body
  assert_eq(r.files[1].content, "pkgtype(kind: \"executable\")\nimport { \"moonbitlang/x/uuid\" }\n")
  assert_eq(r.files[2].content, "fn main raise { }")
}

test "多行 import 全部迁移且行号按偏移重算" {
  let b = @markdown.make_block(5, 10, "import { \"a\" }\nimport { \"b\" }\nlet x = 1", @markdown.compile_kind())
  let r = synth_block(b, 0, "a.md")
  assert_eq(r.files[1].content, "import { \"a\" }\nimport { \"b\" }\n")
  assert_eq(r.files[2].content, "let x = 1")
  // import_count=2，body 首行(原第3行) ↔ 文档行 5+2+0+1 = 8
  assert_eq(r.line_map[0], 8)
}

test "import 后跟非 import 行则后续不迁移" {
  let b = @markdown.make_block(1, 4, "import { \"a\" }\nlet y = 2\nimport { \"b\" }", @markdown.compile_kind())
  let r = synth_block(b, 0, "a.md")
  // 仅顶部连续 import 迁移；第 3 行的 import 因被非 import 行隔断，留在 body
  assert_eq(r.files[1].content, "import { \"a\" }\n")
  assert_eq(r.files[2].content, "let y = 2\nimport { \"b\" }")
}

test "无 import 时 moon.pkg 与 main.mbt 保持原样" {
  let b = @markdown.make_block(1, 2, "let x = 1", @markdown.compile_kind())
  let r = synth_block(b, 0, "x.md")
  assert_eq(r.files[1].content, "")
  assert_eq(r.files[2].content, "let x = 1")
  assert_eq(r.line_map[0], 2)
}
