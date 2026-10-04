///|
/// features/scan — 扫描待验证的文档（.md）与源码（.mbt）
///
/// 复用 platform/fs 的递归列出能力；排除构建产物目录（_build/target/.git/
/// node_modules），避免把生成文件当文档验证。

///|
/// 返回目录下所有 Markdown 文档（.md），已排除构建目录。
pub fn scan_docs(root : String) -> Array[String] {
  scan_ext(root, ".md")
}

///|
/// 返回目录下所有 MoonBit 源文件（.mbt），已排除构建目录。
/// 用于 doccomment 源码验证（含自举）。
pub fn scan_sources(root : String) -> Array[String] {
  scan_ext(root, ".mbt")
}

///|
/// 按扩展名递归列出并过滤。
fn scan_ext(root : String, ext : String) -> Array[String] {
  let files = @fs.list_files(root, ext, 8)
  let out : Array[String] = []
  for f in files {
    if not_build(f) {
      out.push(f)
    }
  }
  out
}

///|
/// 是否应排除（构建产物/版本控制目录）。
///
/// 注意分隔符：Windows 路径用 `\`，Linux/macOS 用 `/`，因此 target
/// 目录的两种写法都匹配（`_build` / `.git` / `node_modules` 是子串匹配，
/// 不受分隔符影响）。
fn not_build(path : String) -> Bool {
  !path.contains("_build") && !path.contains("/target/") &&
  !path.contains("\\target\\") && !path.contains(".git") &&
  !path.contains("node_modules")
}
