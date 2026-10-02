///|
/// cmd/moonproof — CLI 入口
///
/// 用法：moon run cmd/moonproof -- [目录] [--timeout <ms>]
///   目录默认当前目录；验证其中所有 .md 文档里的 moonbit 代码块。
///   退出码：0 = 全部通过；1 = 有失败；2 = 运行错误。
fn main {
  let argv = @env.args()
  let mut root = "."
  let mut timeout_ms = 60000
  let mut verbose = false
  let mut i = 1
  while i < argv.length() {
    let a = argv[i]
    if a == "--timeout" && i + 1 < argv.length() {
      timeout_ms = parse_int(argv[i + 1])
      i = i + 2
    } else if a == "--verbose" || a == "-v" {
      verbose = true
      i = i + 1
    } else if a == "--help" || a == "-h" {
      print_usage()
      @proc.exit_with(0)
    } else if a.has_prefix("--") {
      println("unknown option: " + a)
      @proc.exit_with(2)
    } else {
      root = a
      i = i + 1
    }
  }
  let opts = @run.make_options(timeout_ms)
  match @run.run_docs(root, opts) {
    Ok(reports) => {
      let mut any_fail = false
      for r in reports {
        if verbose {
          println(@report.render_text_verbose(r))
        } else {
          println(@report.render_text(r))
        }
        if r.failed > 0 {
          any_fail = true
        }
      }
      if any_fail {
        @proc.exit_with(1)
      } else {
        @proc.exit_with(0)
      }
    }
    Err(e) => {
      println("error: " + e)
      @proc.exit_with(2)
    }
  }
}

///|
fn print_usage() -> Unit {
  println("MoonProof — 验证 MoonBit 文档与教程里的代码示例")
  println("用法: moon run cmd/moonproof -- [目录] [--timeout <毫秒>] [--verbose]")
}

///|
/// 尽力解析整数；失败回退到默认。
fn parse_int(s : String) -> Int {
  let mut n = 0
  for c in s {
    if c >= '0' && c <= '9' {
      n = n * 10 + (c.to_int() - '0'.to_int())
    } else {
      return n
    }
  }
  n
}
