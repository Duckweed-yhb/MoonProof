///|
/// exec/toolchain — 调起 moon check / moon test
///
/// 通过 platform/proc 在指定模块目录执行真实 moon 工具链，返回退出码、
/// stdout、stderr。超时由 proc 层控制。
///
/// moon 可执行路径解析顺序：
///   1. 环境变量 MOON_BIN（显式指定）
///   2. 标准安装位置 `~/.moon/bin/moon(.exe)`（按 USERPROFILE/HOME 推导）
///   3. 退回裸命令 `moon`（依赖 shell 的 PATH）
/// 用全路径是为了不依赖调用方的 PATH 环境，保证在干净环境也能复现。

///|
/// 一次工具链执行的结果
pub struct ToolOutput {
  exit_code : Int
  stdout : String
  stderr : String
}

///|
/// 在 module_dir 中执行 `moon check`（默认验证动作）。
/// target 非空时附加 `--target <target>`（如 "wasm" / "js" / "native"），
/// 空串则使用 moon 的默认后端。
pub fn moon_check(module_dir : String, timeout_ms : Int, target : String) -> Result[ToolOutput, String] {
  run_tool("check", module_dir, target, timeout_ms)
}

///|
/// 在 module_dir 中执行 `moon test`（Run 标注的验证动作）。
pub fn moon_test(module_dir : String, timeout_ms : Int, target : String) -> Result[ToolOutput, String] {
  run_tool("test", module_dir, target, timeout_ms)
}

///|
/// 在 module_dir 中执行 `moon run main`（Run 标注：真正运行示例 main）。
pub fn moon_run(module_dir : String, timeout_ms : Int, target : String) -> Result[ToolOutput, String] {
  run_tool("run main", module_dir, target, timeout_ms)
}

///|
/// 在 module_dir 中执行 `moon add <dep>`（注入第三方依赖，供文档示例 import）。
/// 依赖名形如 "owner/name"，由工具链解析版本并写入 moon.mod。
pub fn moon_add(module_dir : String, dep : String, timeout_ms : Int) -> Result[ToolOutput, String] {
  run_tool("add " + dep, module_dir, "", timeout_ms)
}

///|
/// 通用工具链执行。失败（无法创建进程等）返回 Err；命令本身非零退出码不算失败。
fn run_tool(
  sub : String,
  module_dir : String,
  target : String,
  timeout_ms : Int
) -> Result[ToolOutput, String] {
  let cmd = moon_command(sub, target)
  match @proc.run(cmd, module_dir, timeout_ms) {
    Ok(o) => Ok({ exit_code: o.exit_code, stdout: o.stdout, stderr: o.stderr })
    Err(e) => Err(proc_error_message(e))
  }
}

///|
/// 组装 moon 命令：`<moon_exe> <sub> [--target <t>]`，exe 加引号以防路径含空格。
fn moon_command(sub : String, target : String) -> String {
  let mut c = quote(moon_exe()) + " " + sub
  if target.length() > 0 {
    c = c + " --target " + target
  }
  c
}

///|
/// 解析 moon 可执行路径。
fn moon_exe() -> String {
  match @env.get_env_var("MOON_BIN") {
    Some(p) =>
      if p.length() > 0 {
        return p
      }
    None => ()
  }
  let home = match @env.get_env_var("USERPROFILE") {
    Some(p) => p
    None => ""
  }
  let home2 = match @env.get_env_var("HOME") {
    Some(p) => p
    None => home
  }
  if home2.length() > 0 {
    let bin = @proc.join_path(@proc.join_path(home2, ".moon"), "bin")
    let exe = @proc.join_path(bin, moon_bin_name())
    if @fs.exists(exe) {
      return exe
    }
  }
  // 退回 PATH（例如 MOON_BIN 未设、标准位置不存在时）
  "moon"
}

#cfg(platform="windows")
fn moon_bin_name() -> String {
  "moon.exe"
}

#cfg(not(platform="windows"))
fn moon_bin_name() -> String {
  "moon"
}

///|
/// 给命令路径加双引号，避免含空格路径被 shell 拆开。
fn quote(p : String) -> String {
  "\"" + p + "\""
}

///|
/// 把 ProcError 转成可读消息。
fn proc_error_message(e : @proc.ProcError) -> String {
  @proc.error_message(e)
}
