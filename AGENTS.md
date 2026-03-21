# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod.json` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. Use snapshot tests to record current
  behavior. For solid, well-defined results (e.g. scientific computations),
  prefer assertion tests. You can use `moon coverage analyze > uncovered.log` to
  see which parts of your code are not covered by tests.

## Project Status: MoonBit Console Library

### Goal

Implement a MoonBit console library by porting .NET Runtime `System.Console` 
using MoonBit C FFI bindings to native system calls (Unix only).

### Key Discovery: FFI `#borrow` Syntax

When declaring extern "c" functions with `Bytes` parameters, the ownership 
annotation must be placed with `///|` BEFORE the `#borrow` annotation:

```moonbit
///|          <- doc comment FIRST
#borrow(buffer)  <- then the annotation with parameter name
extern "c" fn console_write(fd : Int, buffer : Bytes, size : Int) -> Int = "console_write"
```

NOT on the same line as the parameter: `fn foo(#borrow buffer : Bytes)` - this causes parse errors.

### Files

```
console/
├── moon.mod.json          # Module config with native target + utf8 import
├── moon.pkg              # Main package config
├── ffi/
│   ├── moon.pkg          # FFI package config with native-stub
│   ├── ffi.mbt           # FFI declarations (write, isatty, etc.)
│   └── stub_unix.c       # C native stubs using moonbit.h
├── console_unix.mbt      # Unix console implementation (write, colors, cursor)
├── types.mbt             # ConsoleColor, ConsoleKey, ConsoleKeyInfo enums
└── _build/               # Build output
```

### Current State

- ✅ Build succeeds (0 warnings, 0 errors)
- ✅ Basic output functions: write, write_line, error_write_line
- ✅ Color functions: set_foreground_color, set_background_color, reset_color
- ✅ Cursor functions: hide_cursor, show_cursor, move_cursor_*, set_cursor_position
- ✅ Clear functions: clear, clear_line, clear_to_end_of_line
- ✅ Utility: beep, is_input_redirected, is_output_redirected, get_window_size
- ⏳ Read input functions not yet tested
- ⏳ Tests not yet written
