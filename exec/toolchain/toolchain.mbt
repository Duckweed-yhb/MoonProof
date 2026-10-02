///|
/// exec/toolchain — 调起 moon check / moon test
///
/// 通过 platform/proc 在指定模块目录执行真实 moon 工具链，返回退出码、
/// stdout、stderr。超时由 proc 层控制。

///|
/// 一次工具链执行的结果
pub struct ToolOutput {
  exit_code : Int
  stdout : String
  stderr : String
}

///|
/// 在 module_dir 中执行 `moon check`（默认验证动作）。
pub fn moon_check(module_dir : String, timeout_ms : Int) -> Result[ToolOutput, String] {
  run_tool("moon check", module_dir, timeout_ms)
}

///|
/// 在 module_dir 中执行 `moon test`（Run 标注的验证动作）。
pub fn moon_test(module_dir : String, timeout_ms : Int) -> Result[ToolOutput, String] {
  run_tool("moon test", module_dir, timeout_ms)
}

///|
/// 通用工具链执行。失败（无法创建进程等）返回 Err；命令本身非零退出码不算失败。
fn run_tool(cmd : String, module_dir : String, timeout_ms : Int) -> Result[ToolOutput, String] {
  match @proc.run(cmd, module_dir, timeout_ms) {
    Ok(o) => Ok({ exit_code: o.exit_code, stdout: o.stdout, stderr: o.stderr })
    Err(e) => Err(proc_error_message(e))
  }
}

///|
/// 把 ProcError 转成可读消息。
fn proc_error_message(e : @proc.ProcError) -> String {
  @proc.error_message(e)
}
