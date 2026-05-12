# han.test Test Tools

`han.test` is a tiny test framework used by han and early TAFFISH self-checks.

## Role

It avoids introducing external test dependencies, so the base library can define and run tests very early in the load process.

## Core APIs

| API | Role |
| --- | --- |
| `*tests*` | Registered test list. |
| `reset-tests` | Clear tests. |
| `deftest` | Define a test. |
| `run-test` | Run one test. |
| `run-all-tests` | Run all tests. |
| `check-true` | Assert non-nil. |
| `check-false` | Assert nil. |
| `check-equal` | Compare with `equal`. |
| `check-error` | Assert that a condition is signaled. |

## Behavior

`deftest` overwrites old tests by name, preventing duplicate entries after loading the same test file repeatedly.

`run-all-tests` returns two values:

```lisp
passed, failed
```

and prints a summary.

## Modification Guide

`han.test` should remain small and stable. Do not turn it into a complex test runner, fixture system, or mock system.

If a fuller test framework is needed later, introduce it at the project test layer. `han.test` should remain as the base bootstrap tool.

