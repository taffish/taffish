# Module Documentation Template

Every important directory or file should be documented with a consistent logic. The goal is not formal neatness; the goal is to let maintainers build the correct mental model quickly.

## Recommended Template

```markdown
# Module Name

## Role

Explain why this code exists, what problem it solves, and what it does not solve.

## System Position

Explain which TAFFISH layer it belongs to, who is upstream, and who is downstream.

## Upstream And Downstream Interaction

Explain what structures it receives, what structures it returns, which modules it calls, and which modules call it.

## Core Data Structures Or Invariants

List the rules maintainers must not break, such as field meanings, path conventions, error types, return shapes, and load order.

## Public API

List functions, macros, variables, or classes that external modules should call. Only include stable or semi-stable interfaces.

## Implementation Notes

Explain implementation details that are easy to misunderstand. Do not explain code line by line; explain why it is written this way.

## Modification Guide

Tell future maintainers what to check when changing this module, what problems are easy to introduce, and what tests or docs should be added.
```

## Writing Requirements

Each module document should answer at least four questions:

1. What is this code responsible for, and where is the boundary?
2. Where does it sit in the complete flow?
3. Which input contracts does it rely on, and which output contracts does it promise downstream?
4. What is the easiest thing to break when modifying it?

## Discouraged Style

Avoid writing only a function list:

```markdown
## API

- `foo`
- `bar`
- `baz`
```

That style is not very helpful for maintenance because future maintainers still do not know why the functions exist, when to call them, or how system state changes before and after the call.

## Recommended Style

A better style explains the meaning of the module first:

```markdown
## Role

`binder` is the semantic binding layer between parser and compiler. The parser only understands source structure; the binder attaches external input arguments and runtime context to the program, producing a result that the compiler can consume directly.

## Invariants

- The parser does not read actual user input values.
- The binder does not reinterpret TAF source syntax.
- The compiler does not read CLI arguments directly.
```

This kind of content helps maintainers decide where a new feature belongs.

