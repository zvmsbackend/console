# sennenki/console

Cross-platform console bindings for MoonBit, inspired by .NET `System.Console`.

The package currently targets native platforms and provides:

- text output (`write`, `write_line`, `newline`, error stream variants)
- keyboard input (`read`, `read_line`, `read_key`, `key_available`)
- cursor control and screen clearing
- foreground/background colors
- window and buffer size APIs
- Ctrl+C / Ctrl+Break handler registration

## Package layout

- `console.mbt`: shared public entry helpers
- `console_unix.mbt`: Unix implementation (`#cfg(not(platform="windows"))`)
- `console_windows.mbt`: Windows implementation (`#cfg(platform="windows")`)
- `types.mbt`: public enums and key info types
- `ffi/ffi.mbt`: native FFI declarations
- `ffi/stub_unix.c`, `ffi/stub_windows.c`: platform C stubs

## Quick usage

```moonbit nocheck
@console.write_line("hello")
let line = @console.read_line()
@console.write_line("you typed: \{line}")
```

## Cancel key handlers

Register handlers with:

```moonbit nocheck
///|
let id = @console.add_cancel_key_press_handler(fn(key) {
  match key {
    ControlC => @console.write_line("ctrl-c")
    ControlBreak => @console.write_line("ctrl-break")
  }
  true // true => handled, false => default terminate behavior
})
```

Unregister with `@console.remove_cancel_key_press_handler(id)`.

### Sync and async dispatch

- Sync APIs (`read`, `read_key`, `read_line`, `key_available`) perform cooperative pending-signal checks.
- For async runtimes, you can run cooperative async polling with:

```moonbit nocheck
@console.start_async_cancel_dispatcher()
```

Call it from an async task context.

## Platform differences

### Unix

- Uses terminal/ANSI control where applicable.
- Some window/buffer APIs are compatibility fallbacks (depends on terminal support).

### Windows

- Uses Win32 console APIs for key input, cursor, colors, title, buffer/window operations.
- Signal behavior differs between `CTRL_BREAK_EVENT` and `CTRL_C_EVENT`; automation is usually more stable with `CTRL_BREAK_EVENT`.

## .NET alignment notes

This library follows `.NET Console` semantics where practical, with MoonBit-specific constraints:

- no method overloading: use generic `write`/`write_line` (Show-based) and explicit API names
- error handling currently uses `abort`-style failures in many places rather than .NET exception types
- APIs unsupported on a platform may be absent or constrained by `#cfg`

## Testing

### Unit/whitebox

```bash
moon test
```

### Linux integration

```bash
python3 integration/run_linux_integration.py
```

### Windows integration

```powershell
python integration/run_windows_integration.py
```

The Windows harness treats `CTRL_BREAK_EVENT` signal cases as required and `CTRL_C_EVENT` cases as best-effort.
