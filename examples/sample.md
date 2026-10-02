# MoonProof 示例文档

这份文档用于端到端验证 MoonProof：每种标注对应一个代码块。

## 可编译的代码块（compile，默认）

```moonbit
fn add(a : Int, b : Int) -> Int {
  a + b
}
```

## 可运行的代码块（run）

```moonbit run
fn main {
  println("hello from moonproof")
}
```

## 跳过的代码块（no-check）

```moonbit no-check
fn not_checked() -> Int {
  ??? // 不会被验证
}
```

## 期望失败的代码块（should-fail）

```moonbit should-fail
fn broken() -> Int {
  "not an int" // 类型错误，应当编译失败
}
```
