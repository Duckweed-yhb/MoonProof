///|
/// cmd/moonproof — CLI 入口
///
/// 用法：moon run --target native cmd/moonproof -- [目录] [--timeout <ms>] [--verbose]
///   目录默认当前目录；验证其中所有 .md 文档里的 moonbit 代码块。
///   退出码：0 = 全部通过；1 = 有失败；2 = 运行错误。
/// 错误码验证：moon run --target native cmd/moonproof -- --errorcodes <error_codes 根目录>
///|
/// 解析后的命令行参数（纯数据，便于单元测试）。
pub struct ParsedArgs {
  /// 目标目录（默认 ".")
  root : String
  /// 单块编译超时（毫秒，默认 60000）
  timeout_ms : Int
  /// 是否 --verbose / -v
  verbose : Bool
  /// --errorcodes 的根目录（非空即错误码验证模式）
  err_dir : String
  /// --out 的 JSON 输出路径（仅错误码模式）
  out_path : String
  /// --target 的验证后端（wasm / js / native；空串表示不指定）
  target : String
  /// --dep 注入的第三方依赖（可重复，形如 "owner/name"）
  deps : Array[String]
  /// 解析结果动作：docs / errorcodes / help / error
  action : String
  /// action == "error" 时的提示
  error : String
}

///|
/// 解析命令行参数（argv[0] 为程序名，从 argv[1] 开始）。纯函数，不触发任何
/// 副作用（不打印、不退出），由 main 依据 action 分发。可被单元测试覆盖。
fn parse_args(argv : Array[String]) -> ParsedArgs {
  let mut root = "."
  let mut timeout_ms = 60000
  let mut verbose = false
  let mut err_dir = ""
  let mut out_path = ""
  let mut target = ""
  let deps : Array[String] = []
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
    } else if a == "--out" && i + 1 < argv.length() {
      out_path = argv[i + 1]
      i = i + 2
    } else if a == "--target" && i + 1 < argv.length() {
      target = argv[i + 1]
      i = i + 2
    } else if a == "--dep" && i + 1 < argv.length() {
      deps.push(argv[i + 1])
      i = i + 2
    } else if a == "--help" || a == "-h" {
      return {
        root,
        timeout_ms,
        verbose,
        err_dir,
        out_path,
        target,
        deps,
        action: "help",
        error: "",
      }
    } else if a.has_prefix("--") {
      return {
        root,
        timeout_ms,
        verbose,
        err_dir,
        out_path,
        target,
        deps,
        action: "error",
        error: "unknown option: " + a,
      }
    } else {
      root = a
      i = i + 1
    }
  }
  if err_dir.length() > 0 {
    { root, timeout_ms, verbose, err_dir, out_path, target, deps, action: "errorcodes", error: "" }
  } else {
    { root, timeout_ms, verbose, err_dir, out_path, target, deps, action: "docs", error: "" }
  }
}

fn main {
  let args = parse_args(@env.args())
  match args.action {
    "help" => {
      print_usage()
      @proc.exit_with(0)
    }
    "error" => {
      println(args.error)
      @proc.exit_with(2)
    }
    "errorcodes" => run_errorcodes(args.err_dir, args.timeout_ms, args.out_path)
    _ => run_docs(
      args.root,
      args.timeout_ms,
      args.verbose,
      args.out_path,
      args.target,
      args.deps,
    )
  }
}

///|
/// 文档验证模式：扫描目录下 .md 里的 moonbit 代码块并验证。
/// out_path 非空时，把全部文档报告导出为 JSON 数组。
/// target 非空时用 `--target <t>` 指定验证后端。
/// deps 非空时对每个依赖执行 `moon add` 注入，供示例 import。
fn run_docs(
  root : String,
  timeout_ms : Int,
  verbose : Bool,
  out_path : String,
  target : String,
  deps : Array[String]
) -> Unit {
  let opts = @run.make_options_with_deps(timeout_ms, target, deps)
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
      if out_path.length() > 0 {
        if @fs.write_text(out_path, reports_to_json(reports)) {
          println("json written to " + out_path)
        } else {
          println("warning: failed to write " + out_path)
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
/// 把多份文档报告渲染为 JSON 数组字符串。
fn reports_to_json(reports : Array[@report.DocReport]) -> String {
  let mut s = "["
  let mut first = true
  for r in reports {
    if first {
      first = false
    } else {
      s = s + ", "
    }
    s = s + @report.to_json(r)
  }
  s + "]"
}

///|
/// 错误码一致性验证模式：验证官方 error_codes 根目录。
fn run_errorcodes(dir : String, timeout_ms : Int, out_path : String) -> Unit {
  let opts = @errorcodes.make_options(timeout_ms)
  match @errorcodes.verify_errorcodes(dir, opts) {
    Ok(report) => {
      println(@errorcodes.render_ec(report))
      if out_path.length() > 0 {
        if @fs.write_text(out_path, @errorcodes.to_json(report)) {
          println("json written to " + out_path)
        } else {
          println("warning: failed to write " + out_path)
        }
      }
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
  println("错误码一致性验证: moon run --target native cmd/moonproof -- --errorcodes <error_codes 根目录> [--timeout <毫秒>] [--out <json 路径>]")
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

// ---------- 单元测试 ----------

test "默认参数：当前目录 + docs 动作 + 默认超时" {
  let a = parse_args(["moonproof"])
  assert_eq(a.action, "docs")
  assert_eq(a.root, ".")
  assert_eq(a.timeout_ms, 60000)
  assert_false(a.verbose)
}

test "--help 返回 help 动作" {
  let a = parse_args(["moonproof", "--help"])
  assert_eq(a.action, "help")
}

test "-v 开启 verbose" {
  let a = parse_args(["moonproof", "-v"])
  assert_true(a.verbose)
}

test "--errorcodes 设置目录并切到 errorcodes 动作" {
  let a = parse_args(["moonproof", "--errorcodes", "some/root"])
  assert_eq(a.action, "errorcodes")
  assert_eq(a.err_dir, "some/root")
}

test "--out 设置 json 输出路径（不改变动作）" {
  let a = parse_args(["moonproof", "--errorcodes", "d", "--out", "report.json"])
  assert_eq(a.action, "errorcodes")
  assert_eq(a.out_path, "report.json")
}

test "--timeout 解析数字" {
  let a = parse_args(["moonproof", "--timeout", "90000"])
  assert_eq(a.timeout_ms, 90000)
}

test "未知选项返回 error 动作并提示" {
  let a = parse_args(["moonproof", "--bogus"])
  assert_eq(a.action, "error")
  assert_true(a.error.contains("bogus"))
}

test "首个非选项参数作为目录" {
  let a = parse_args(["moonproof", "./docs"])
  assert_eq(a.root, "./docs")
}

test "目录与 --verbose 可混用" {
  let a = parse_args(["moonproof", "./docs", "--verbose"])
  assert_eq(a.root, "./docs")
  assert_true(a.verbose)
  assert_eq(a.action, "docs")
}

test "--target 设置验证后端" {
  let a = parse_args(["moonproof", "--target", "wasm"])
  assert_eq(a.target, "wasm")
  assert_eq(a.action, "docs")
}

test "--target 与目录混用" {
  let a = parse_args(["moonproof", "./docs", "--target", "js"])
  assert_eq(a.root, "./docs")
  assert_eq(a.target, "js")
}

test "--dep 收集单个依赖" {
  let a = parse_args(["moonproof", "--dep", "oboard/eval"])
  assert_eq(a.deps.length(), 1)
  assert_eq(a.deps[0], "oboard/eval")
}

test "--dep 可重复收集多个依赖" {
  let a = parse_args(["moonproof", "--dep", "moonbitlang/async", "--dep", "oboard/eval"])
  assert_eq(a.deps.length(), 2)
  assert_eq(a.deps[0], "moonbitlang/async")
  assert_eq(a.deps[1], "oboard/eval")
}

test "--dep 与目录混用" {
  let a = parse_args(["moonproof", "./docs", "--dep", "owner/lib"])
  assert_eq(a.root, "./docs")
  assert_eq(a.deps[0], "owner/lib")
}

test "parse_int 解析与非法回退" {
  assert_eq(parse_int("123"), 123)
  assert_eq(parse_int("0"), 0)
  assert_eq(parse_int(""), 0)
  assert_eq(parse_int("abc"), 0)
  assert_eq(parse_int("45x"), 45)
}
