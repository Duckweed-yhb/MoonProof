///|
/// cmd/moonproof — CLI 入口
///
/// 用法：moon run --target native cmd/moonproof -- [目录] [--timeout <ms>] [--verbose]
///   目录默认当前目录；验证其中所有 .md 文档里的 moonbit 代码块。
///   退出码：0 = 全部通过；1 = 有失败；2 = 运行错误。
/// 错误码验证：moon run --target native cmd/moonproof -- --errorcodes <error_codes 根目录>
fn main {
  let argv = @env.args()
  let mut root = "."
  let mut timeout_ms = 60000
  let mut verbose = false
  let mut err_dir = ""
  let mut i = 1
  while i < argv.length() {
    let a = argv[i]
    if a == "--timeout" && i + 1 < argv.length() {
      timeout_ms = parse_int(argv[i + 1])
      i = i + 2
    } else if a == "--verbose" || a == "-v" {
      verbose = true
      i = i + 1
    } else if a == "--errorcodes" && i + 1 < argv.length() {
      err_dir = argv[i + 1]
      i = i + 2
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
  if err_dir.length() > 0 {
    run_errorcodes(err_dir, timeout_ms)
  } else {
    run_docs(root, timeout_ms, verbose)
  }
}

///|
/// 文档验证模式：扫描目录下 .md 里的 moonbit 代码块并验证。
fn run_docs(root : String, timeout_ms : Int, verbose : Bool) -> Unit {
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
/// 错误码一致性验证模式：验证官方 error_codes 根目录。
fn run_errorcodes(dir : String, timeout_ms : Int) -> Unit {
  let opts = @errorcodes.make_options(timeout_ms)
  match @errorcodes.verify_errorcodes(dir, opts) {
    Ok(report) => {
      println(@errorcodes.render_ec(report))
      if report.error_triggered == report.error_total && report.fixed_passed == report.fixed_total {
        @proc.exit_with(0)
      } else {
        @proc.exit_with(1)
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
  println("用法: moon run --target native cmd/moonproof -- [目录] [--timeout <毫秒>] [--verbose]")
  println("错误码一致性验证: moon run --target native cmd/moonproof -- --errorcodes <error_codes 根目录> [--timeout <毫秒>]")
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
