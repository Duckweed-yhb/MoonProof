  $ moonproof examples
  (re) == examples[/\\]sample\.md ==
  (re)   pass \[@7\] compile
  (re)   pass \[@15\] run
  (re)   skip \[@23\] no-check
  (re)   pass \[@31\] should-fail
  (re)   total=4 pass=3 fail=0 skip=1

  # 指定 wasm 后端：纯计算层可跨后端，结果应一致
  $ moonproof examples --target wasm
  (re) == examples[/\\]sample\.md ==
  (re)   total=4 pass=3 fail=0 skip=1

  # --out 导出 JSON 报告到指定路径，且内容完整可校验
  $ moonproof examples --out $CRAMTMP/report.json
  (re) == examples[/\\]sample\.md ==
  (re)   total=4 pass=3 fail=0 skip=1
  (re) json written to .*report\.json
  $ test -s $CRAMTMP/report.json
  $ grep '"passed": 3' $CRAMTMP/report.json
  (re) "passed": 3

  # --dep 注入第三方依赖（需网络 moon add；不 import 时结果保持稳定）
  $ moonproof examples --dep moonbitlang/x
  (re) == examples[/\\]sample\.md ==
  (re)   total=4 pass=3 fail=0 skip=1
