# han.test 测试工具

`han.test` 是一个极小测试框架，供 han 和 TAFFISH 早期自测使用。

## 作用

它避免引入外部测试依赖，让基础库在很早的加载阶段就能定义和运行测试。

## 核心 API

| API | 作用 |
| --- | --- |
| `*tests*` | 已注册测试列表。 |
| `reset-tests` | 清空测试。 |
| `deftest` | 定义测试。 |
| `run-test` | 运行单个测试。 |
| `run-all-tests` | 运行全部测试。 |
| `check-true` | 断言非 nil。 |
| `check-false` | 断言 nil。 |
| `check-equal` | 使用 `equal` 比较。 |
| `check-error` | 断言指定 condition 被抛出。 |

## 行为

`deftest` 会按 name 覆盖旧测试，避免重复加载同一个测试文件后出现重复条目。

`run-all-tests` 返回两个值：

```lisp
passed, failed
```

并打印汇总。

## 修改指南

`han.test` 应保持小而稳定。不要把复杂测试 runner、fixture 系统、mock 系统塞进这里。

如果未来需要更完整测试框架，可以在项目测试层引入，但 `han.test` 仍应保留为基础自举工具。
