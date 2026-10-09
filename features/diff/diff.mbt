///|
/// features/diff — 两次验证结果的差分对比（纯计算，全后端可移植）
///
/// 让审计可随时间追踪：把某次运行的结果存成快照，下次运行用 `--compare`
/// 对比，输出"新增失效 / 已修复 / 保持失效 / 新增通过"。
///
/// 快照格式（纯文本，tab 分隔，便于解析与人工阅读）：
///   path\tstart_line\tkind\tstatus
/// 每行对应源文档中的一个代码块。

///|
/// 单个代码块的指纹（快照中的一行）。
pub struct Fingerprint {
  path : String
  start_line : Int
  kind : String
  status : String
}

///|
/// 一次对比得到的块级差异。
pub struct DiffEntry {
  path : String
  start_line : Int
  kind : String
  old_status : String
  new_status : String
  /// new-failure / fixed / still-failing / new-pass / unchanged
  change : String
  /// 新结果侧的归因标签（fail 时有值，用于定位）
  new_verdict : String
}

///|
/// 把多份文档报告序列化为快照文本（供 `--snapshot` 写入）。
pub fn snapshot_lines(reports : Array[@report.DocReport]) -> String {
  let mut s = ""
  for r in reports {
    for b in r.blocks {
      s = s + b.path + "\t" + b.start_line.to_string() + "\t" + b.kind + "\t" + b.status + "\n"
    }
  }
  s
}

///|
/// 解析快照文本为指纹数组。忽略空行与字段不足的行。
pub fn parse_snapshot(text : String) -> Array[Fingerprint] {
  let out : Array[Fingerprint] = []
  for line in text.split("\n") {
    let parts = line.split("\t").to_array()
    if parts.length() == 4 && parts[3].length() > 0 {
      out.push(
        {
          path: parts[0].to_owned(),
          start_line: parse_int(parts[1].to_owned()),
          kind: parts[2].to_owned(),
          status: parts[3].to_owned(),
        },
      )
    }
  }
  out
}

///|
/// 对比旧快照与本次结果，返回非 "unchanged" 的差异。
///
/// 变化判定（按 path + start_line 匹配同一代码块）：
///   - 旧 fail → 新 pass：已修复（fixed）
///   - 旧 fail → 新 fail：保持失效（still-failing）
///   - 旧非 fail（pass/skip）→ 新 fail：新增失效（new-failure）
///   - 旧无此块 → 新 fail：新增失效；→ 新 pass：新增通过（new-pass）
///   - 其余：unchanged（不返回）
pub fn diff(old : Array[Fingerprint], reports : Array[@report.DocReport]) -> Array[DiffEntry] {
  let entries : Array[DiffEntry] = []
  for r in reports {
    for b in r.blocks {
      let oldf = find_old(old, b.path, b.start_line)
      let change = match oldf {
        None =>
          if b.status == "fail" {
            "new-failure"
          } else if b.status == "pass" {
            "new-pass"
          } else {
            "unchanged"
          }
        Some(o) =>
          if o.status == "fail" && b.status == "pass" {
            "fixed"
          } else if o.status == "fail" && b.status == "fail" {
            "still-failing"
          } else if b.status == "fail" {
            "new-failure"
          } else {
            "unchanged"
          }
      }
      if change != "unchanged" {
        let old_status = match oldf {
          Some(o) => o.status
          None => ""
        }
        entries.push(
          {
            path: b.path,
            start_line: b.start_line,
            kind: b.kind,
            old_status,
            new_status: b.status,
            change,
            new_verdict: b.verdict,
          },
        )
      }
    }
  }
  entries
}

///|
/// 在旧快照中按 (path, start_line) 查找指纹。
fn find_old(old : Array[Fingerprint], path : String, line : Int) -> Fingerprint? {
  for o in old {
    if o.path == path && o.start_line == line {
      return Some(o)
    }
  }
  None
}

///|
/// 渲染差异报告：先统计，再列出"新增失效 / 已修复 / 保持失效 / 新增通过"明细。
pub fn render_diff(entries : Array[DiffEntry]) -> String {
  let mut nf = 0
  let mut fixed = 0
  let mut sf = 0
  let mut np = 0
  for e in entries {
    match e.change {
      "new-failure" => nf = nf + 1
      "fixed" => fixed = fixed + 1
      "still-failing" => sf = sf + 1
      "new-pass" => np = np + 1
      _ => ()
    }
  }
  let mut s = "== 差分（本次 vs 快照） ==\n"
  s = s + "  新增失效: " + nf.to_string()
  s = s + " | 已修复: " + fixed.to_string()
  s = s + " | 保持失效: " + sf.to_string()
  s = s + " | 新增通过: " + np.to_string() + "\n"
  for e in entries {
    if e.change == "new-failure" {
      s = s + "  [新失效] " + e.path + ":" + e.start_line.to_string() + " (" + e.kind + ") " + e.new_verdict + "\n"
    } else if e.change == "fixed" {
      s = s + "  [已修复] " + e.path + ":" + e.start_line.to_string() + "\n"
    } else if e.change == "still-failing" {
      s = s + "  [仍失败] " + e.path + ":" + e.start_line.to_string() + " (" + e.kind + ") " + e.new_verdict + "\n"
    } else if e.change == "new-pass" {
      s = s + "  [新增通过] " + e.path + ":" + e.start_line.to_string() + "\n"
    }
  }
  s
}

///|
/// 尽力解析整数；非法回退 0。
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

// ---------- 测试 ----------

fn fp(path : String, line : Int, status : String) -> Fingerprint {
  { path, start_line: line, kind: "compile", status }
}

test "快照序列化往返一致" {
  let b1 = @report.make_block_result("a.md", 3, "compile", "pass", "", "", "")
  let b2 = @report.make_block_result("a.md", 10, "compile", "fail", "api-changed", "d", "s")
  let r = @report.make_report("a.md", [b1, b2])
  let snap = snapshot_lines([r])
  let parsed = parse_snapshot(snap)
  assert_eq(parsed.length(), 2)
  assert_eq(parsed[0].path, "a.md")
  assert_eq(parsed[0].start_line, 3)
  assert_eq(parsed[0].status, "pass")
  assert_eq(parsed[1].status, "fail")
}

test "解析忽略空行与残缺行" {
  let parsed = parse_snapshot("a.md\t3\tcompile\tpass\n\nbad\tline\n")
  assert_eq(parsed.length(), 1)
  assert_eq(parsed[0].path, "a.md")
}

test "旧 fail 新 pass 判定为已修复" {
  let old = [fp("a.md", 3, "fail")]
  let b = @report.make_block_result("a.md", 3, "compile", "pass", "", "", "")
  let entries = diff(old, [@report.make_report("a.md", [b])])
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].change, "fixed")
  assert_eq(entries[0].old_status, "fail")
  assert_eq(entries[0].new_status, "pass")
}

test "旧 pass 新 fail 判定为新增失效并带归因" {
  let old = [fp("a.md", 3, "pass")]
  let b = @report.make_block_result("a.md", 3, "compile", "fail", "api-changed", "d", "s")
  let entries = diff(old, [@report.make_report("a.md", [b])])
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].change, "new-failure")
  assert_eq(entries[0].new_verdict, "api-changed")
}

test "旧 fail 新 fail 判定为保持失效" {
  let old = [fp("a.md", 3, "fail")]
  let b = @report.make_block_result("a.md", 3, "compile", "fail", "compile-error", "d", "s")
  let entries = diff(old, [@report.make_report("a.md", [b])])
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].change, "still-failing")
}

test "旧无此块 新 pass 判定为新增通过" {
  let old = []
  let b = @report.make_block_result("a.md", 5, "compile", "pass", "", "", "")
  let entries = diff(old, [@report.make_report("a.md", [b])])
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].change, "new-pass")
}

test "两次一致不产生差异" {
  let old = [fp("a.md", 3, "pass"), fp("a.md", 9, "skip")]
  let b1 = @report.make_block_result("a.md", 3, "compile", "pass", "", "", "")
  let b2 = @report.make_block_result("a.md", 9, "compile", "skip", "", "", "")
  let entries = diff(old, [@report.make_report("a.md", [b1, b2])])
  assert_eq(entries.length(), 0)
}

test "渲染包含统计与明细" {
  let old = [fp("a.md", 3, "fail"), fp("a.md", 10, "pass")]
  let b1 = @report.make_block_result("a.md", 3, "compile", "pass", "", "", "")
  let b2 = @report.make_block_result("a.md", 10, "compile", "fail", "api-changed", "d", "s")
  let t = render_diff(diff(old, [@report.make_report("a.md", [b1, b2])]))
  assert_true(t.contains("已修复: 1"))
  assert_true(t.contains("新增失效: 1"))
  assert_true(t.contains("[已修复]"))
  assert_true(t.contains("[新失效]"))
}
