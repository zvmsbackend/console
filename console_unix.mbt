// console_unix.mbt - Unix console implementation

///|
const STDIN_FD = 0

///|
const STDOUT_FS = 1

///|
const STDERR_FD = 2

///|
pub fn is_input_redirected() -> Bool {
  !@ffi.isatty(STDIN_FD)
}

///|
pub fn is_output_redirected() -> Bool {
  !@ffi.isatty(STDOUT_FS)
}

///|
pub fn is_error_redirected() -> Bool {
  !@ffi.isatty(STDERR_FD)
}

///|
pub fn write(s : String) -> Int {
  let bytes = @utf8.encode(s)
  @ffi.write_fd(STDOUT_FS, bytes, bytes.length())
}

///|
pub fn write_line(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDOUT_FS, bytes, bytes.length())
  let _ = @ffi.write_fd(STDOUT_FS, @utf8.encode("\n"), 1)
  n
}

///|
pub fn error_write_line(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDERR_FD, bytes, bytes.length())
  let _ = @ffi.write_fd(STDERR_FD, @utf8.encode("\n"), 1)
  n
}

///|
pub fn get_window_size() -> (Int, Int) {
  let width = @ffi.get_window_width()
  let height = @ffi.get_window_height()
  (width, height)
}

///|
pub fn clear() -> Unit {
  if !is_output_redirected() {
    write("\u{1b}[2J\u{1b}[H") |> ignore
  }
}

///|
pub fn set_foreground_color(color : ConsoleColor) -> Unit {
  if !is_output_redirected() {
    let cmd = "\u{1b}[3\{color.to_int()}m"
    write(cmd) |> ignore
  }
}

///|
pub fn set_background_color(color : ConsoleColor) -> Unit {
  if !is_output_redirected() {
    let cmd = "\u{1b}[4\{color.to_int()}m"
    write(cmd) |> ignore
  }
}

///|
pub fn reset_color() -> Unit {
  if !is_output_redirected() {
    write("\u{1b}[0m") |> ignore
  }
}

///|
pub fn beep() -> Unit {
  if !is_output_redirected() {
    write("\u{07}") |> ignore
  }
}

///|
pub fn hide_cursor() -> Unit {
  if !is_output_redirected() {
    write("\u{1b}[?25l") |> ignore
  }
}

///|
pub fn show_cursor() -> Unit {
  if !is_output_redirected() {
    write("\u{1b}[?25h") |> ignore
  }
}

///|
pub fn clear_line() -> Unit {
  if !is_output_redirected() {
    write("\u{1b}[2K") |> ignore
  }
}

///|
pub fn clear_to_end_of_line() -> Unit {
  if !is_output_redirected() {
    write("\u{1b}[K") |> ignore
  }
}

///|
pub fn move_cursor_up(lines : Int) -> Unit {
  if !is_output_redirected() && lines > 0 {
    let cmd = "\u{1b}[\{lines}A"
    write(cmd) |> ignore
  }
}

///|
pub fn move_cursor_down(lines : Int) -> Unit {
  if !is_output_redirected() && lines > 0 {
    let cmd = "\u{1b}[\{lines}B"
    write(cmd) |> ignore
  }
}

///|
pub fn move_cursor_right(cols : Int) -> Unit {
  if !is_output_redirected() && cols > 0 {
    let cmd = "\u{1b}[\{cols}C"
    write(cmd) |> ignore
  }
}

///|
pub fn move_cursor_left(cols : Int) -> Unit {
  if !is_output_redirected() && cols > 0 {
    let cmd = "\u{1b}[\{cols}D"
    write(cmd) |> ignore
  }
}

///|
pub fn set_cursor_position(left : Int, top : Int) -> Unit {
  if !is_output_redirected() {
    let cmd = "\u{1b}[\{top + 1};\{left + 1}H"
    write(cmd) |> ignore
  }
}

///|
pub fn key_available() -> Bool {
  @ffi.stdin_ready()
}

///|
pub fn read_key(intercept : Bool) -> ConsoleKeyInfo {
  let _ = @ffi.init_terminal()
  let info = read_key_raw(intercept)
  @ffi.uninit_terminal()
  info
}

///|
fn read_key_raw(intercept : Bool) -> ConsoleKeyInfo {
  let first = read_byte_blocking()
  if first == 27 {
    if !key_available() {
      if !intercept {
        write("\u{1b}") |> ignore
      }
      return {
        key_char: (27).unsafe_to_char(),
        key: Escape,
        shift: false,
        alt: false,
        control: false,
      }
    }
    let second = read_byte_blocking()
    if second == 91 {
      let third = read_byte_blocking()
      let key = match third {
        65 => UpArrow
        66 => DownArrow
        67 => RightArrow
        68 => LeftArrow
        _ => Escape
      }
      return {
        key_char: (0).unsafe_to_char(),
        key,
        shift: false,
        alt: false,
        control: false,
      }
    }
    return {
      key_char: (27).unsafe_to_char(),
      key: Escape,
      shift: false,
      alt: true,
      control: false,
    }
  }

  let normalized = if first >= 97 && first <= 122 { first - 32 } else { first }
  let key = ConsoleKey::from_ascii(normalized)
  let shift = first >= 65 && first <= 90
  let control = first >= 1 && first <= 26

  if !intercept {
    write(first.unsafe_to_char().to_string()) |> ignore
  }

  { key_char: first.unsafe_to_char(), key, shift, alt: false, control }
}

///|
fn read_byte_blocking() -> Int {
  let buffer = Bytes::new(1)
  while true {
    let n = @ffi.read_stdin(buffer, 1)
    if n > 0 {
      return buffer[0].to_int()
    }
    if n < 0 {
      return 0
    }
  }
  0
}

///|
fn ConsoleKey::from_ascii(code : Int) -> ConsoleKey {
  match code {
    8 => Backspace
    9 => Tab
    10 => Enter
    13 => Enter
    27 => Escape
    32 => Space
    48 => D0
    49 => D1
    50 => D2
    51 => D3
    52 => D4
    53 => D5
    54 => D6
    55 => D7
    56 => D8
    57 => D9
    65 => A
    66 => B
    67 => C
    68 => D
    69 => E
    70 => F
    71 => G
    72 => H
    73 => I
    74 => J
    75 => K
    76 => L
    77 => M
    78 => N
    79 => O
    80 => P
    81 => Q
    82 => R
    83 => S
    84 => T
    85 => U
    86 => V
    87 => W
    88 => X
    89 => Y
    90 => Z
    _ => Space
  }
}
