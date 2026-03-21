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
fn write_mono(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDOUT_FS, bytes, bytes.length())
  if n < 0 {
    abort("console write failed")
  }
  n
}

///|
fn write_line_mono(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDOUT_FS, bytes, bytes.length())
  @ffi.write_fd(STDOUT_FS, @utf8.encode("\n"), 1) |> ignore
  n
}

///|
pub fn error_write(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDERR_FD, bytes, bytes.length())
  if n < 0 {
    abort("console error write failed")
  }
  n
}

///|
pub fn error_write_line(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDERR_FD, bytes, bytes.length())
  @ffi.write_fd(STDERR_FD, @utf8.encode("\n"), 1) |> ignore
  n
}

///|
pub fn get_window_size() -> (Int, Int) {
  let width = @ffi.get_window_width()
  let height = @ffi.get_window_height()
  (width, height)
}

///|
pub fn get_window_width() -> Int {
  @ffi.get_window_width()
}

///|
pub fn get_window_height() -> Int {
  @ffi.get_window_height()
}

///|
pub fn get_buffer_width() -> Int {
  get_window_width()
}

///|
pub fn get_buffer_height() -> Int {
  get_window_height()
}

///|
pub fn get_largest_window_width() -> Int {
  get_window_width()
}

///|
pub fn get_largest_window_height() -> Int {
  get_window_height()
}

///|
pub fn clear() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[2J\u{1b}[H") |> ignore
  }
}

///|
pub fn set_foreground_color(color : ConsoleColor) -> Unit {
  if !is_output_redirected() {
    let cmd = "\u{1b}[3\{color.to_int()}m"
    write_mono(cmd) |> ignore
  }
}

///|
pub fn set_background_color(color : ConsoleColor) -> Unit {
  if !is_output_redirected() {
    let cmd = "\u{1b}[4\{color.to_int()}m"
    write_mono(cmd) |> ignore
  }
}

///|
pub fn reset_color() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[0m") |> ignore
  }
}

///|
pub fn beep() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{07}") |> ignore
  }
}

///|
pub fn hide_cursor() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[?25l") |> ignore
  }
}

///|
pub fn set_cursor_visible(visible : Bool) -> Unit {
  if visible {
    show_cursor()
  } else {
    hide_cursor()
  }
}

///|
pub fn show_cursor() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[?25h") |> ignore
  }
}

///|
pub fn get_treat_control_c_as_input() -> Bool {
  if is_input_redirected() {
    return false
  }
  @ffi.get_signal_break() == 0
}

///|
pub fn set_treat_control_c_as_input(value : Bool) -> Unit {
  if !is_input_redirected() {
    let enable_signal_break = if value { 0 } else { 1 }
    if @ffi.set_signal_break(enable_signal_break) != 0 {
      abort("failed to set signal break mode")
    }
  }
}

///|
pub fn clear_line() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[2K") |> ignore
  }
}

///|
pub fn clear_to_end_of_line() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[K") |> ignore
  }
}

///|
pub fn move_cursor_up(lines : Int) -> Unit {
  if lines < 0 {
    abort("lines must be non-negative")
  }
  if !is_output_redirected() && lines > 0 {
    let cmd = "\u{1b}[\{lines}A"
    write_mono(cmd) |> ignore
  }
}

///|
pub fn move_cursor_down(lines : Int) -> Unit {
  if lines < 0 {
    abort("lines must be non-negative")
  }
  if !is_output_redirected() && lines > 0 {
    let cmd = "\u{1b}[\{lines}B"
    write_mono(cmd) |> ignore
  }
}

///|
pub fn move_cursor_right(cols : Int) -> Unit {
  if cols < 0 {
    abort("cols must be non-negative")
  }
  if !is_output_redirected() && cols > 0 {
    let cmd = "\u{1b}[\{cols}C"
    write_mono(cmd) |> ignore
  }
}

///|
pub fn move_cursor_left(cols : Int) -> Unit {
  if cols < 0 {
    abort("cols must be non-negative")
  }
  if !is_output_redirected() && cols > 0 {
    let cmd = "\u{1b}[\{cols}D"
    write_mono(cmd) |> ignore
  }
}

///|
pub fn set_cursor_position(left : Int, top : Int) -> Unit {
  if left < 0 || top < 0 {
    abort("left/top must be non-negative")
  }
  if !is_output_redirected() {
    let cmd = "\u{1b}[\{top + 1};\{left + 1}H"
    write_mono(cmd) |> ignore
  }
}

///|
pub fn get_cursor_position() -> (Int, Int) {
  if is_input_redirected() || is_output_redirected() {
    return (0, 0)
  }

  if @ffi.init_terminal() != 0 {
    return (0, 0)
  }

  write_mono("\u{1b}[6n") |> ignore
  let report = read_escape_response()
  @ffi.uninit_terminal()

  if report is Some(bytes) {
    if parse_cursor_report(bytes) is Some((left, top)) {
      return (left, top)
    }
  }
  (0, 0)
}

///|
pub fn get_cursor_left() -> Int {
  let (left, _) = get_cursor_position()
  left
}

///|
pub fn get_cursor_top() -> Int {
  let (_, top) = get_cursor_position()
  top
}

///|
pub fn key_available() -> Bool {
  @ffi.stdin_ready()
}

///|
pub fn read() -> Int {
  if is_input_redirected() {
    abort("Console.Read requires interactive stdin")
  }
  let _ = @ffi.init_terminal()
  let ch = read_byte_blocking()
  @ffi.uninit_terminal()
  if ch < 0 {
    -1
  } else {
    ch
  }
}

///|
pub fn read_key(intercept? : Bool = false) -> ConsoleKeyInfo {
  if is_input_redirected() {
    abort("Console.ReadKey requires interactive stdin")
  }
  let _ = @ffi.init_terminal()
  let info = read_key_raw(intercept)
  @ffi.uninit_terminal()
  info
}

///|
fn read_key_raw(intercept : Bool) -> ConsoleKeyInfo {
  let first = read_byte_blocking()
  if first < 0 {
    return ConsoleKeyInfo::new('\u0000', Space, false, false, false)
  }
  if first == 27 {
    if !key_available() {
      if !intercept {
        write_mono("\u{1b}") |> ignore
      }
      return ConsoleKeyInfo::new('\u001b', Escape, false, false, false)
    }
    let second = read_byte_blocking()
    if second == 91 {
      return read_csi_key()
    }
    if second == 79 {
      return read_ss3_key()
    }
    if second >= 0 {
      let normalized = if second >= 97 && second <= 122 {
        second - 32
      } else {
        second
      }
      let key = ConsoleKey::from_ascii(normalized)
      let shift = second >= 65 && second <= 90
      let control = second >= 1 && second <= 26
      if !intercept && second >= 32 {
        write_mono(second.unsafe_to_char().to_string()) |> ignore
      }
      return ConsoleKeyInfo::new(
        second.unsafe_to_char(),
        key,
        shift,
        true,
        control,
      )
    }
    return ConsoleKeyInfo::new('\u001b', Escape, false, true, false)
  }

  if first >= 128 {
    let ch = read_utf8_char(first)
    if !intercept && !ch.is_control() {
      write_mono(ch.to_string()) |> ignore
    }
    return ConsoleKeyInfo::new(ch, Space, false, false, false)
  }

  let normalized = if first >= 97 && first <= 122 { first - 32 } else { first }
  let key = ConsoleKey::from_ascii(normalized)
  let shift = first >= 65 && first <= 90
  let control = first >= 1 && first <= 26

  if !intercept {
    write_mono(first.unsafe_to_char().to_string()) |> ignore
  }

  ConsoleKeyInfo::new(first.unsafe_to_char(), key, shift, false, control)
}

///|
fn read_ss3_key() -> ConsoleKeyInfo {
  let code = read_byte_blocking()
  let key = match code {
    65 => UpArrow
    66 => DownArrow
    67 => RightArrow
    68 => LeftArrow
    72 => Home
    70 => End
    80 => F1
    81 => F2
    82 => F3
    83 => F4
    _ => Escape
  }
  ConsoleKeyInfo::new('\u0000', key, false, false, false)
}

///|
fn read_csi_key() -> ConsoleKeyInfo {
  let code = read_byte_blocking()
  let key = match code {
    65 => Some(UpArrow)
    66 => Some(DownArrow)
    67 => Some(RightArrow)
    68 => Some(LeftArrow)
    70 => Some(End)
    72 => Some(Home)
    _ => None
  }
  if key is Some(k) {
    return ConsoleKeyInfo::new('\u0000', k, false, false, false)
  }
  if code < 48 || code > 57 {
    return ConsoleKeyInfo::new('\u001b', Escape, false, false, false)
  }

  let mut n = code - 48
  let mut next = read_byte_blocking()
  while next >= 48 && next <= 57 {
    n = n * 10 + (next - 48)
    next = read_byte_blocking()
  }

  if next == 126 {
    let mapped = ConsoleKey::from_csi_tilde_number(n)
    return ConsoleKeyInfo::new('\u0000', mapped, false, false, false)
  }

  if next == 59 {
    let mod_code = read_byte_blocking()
    let final_code = read_byte_blocking()
    let (shift, alt, control) = decode_csi_modifier(mod_code)
    let key = match final_code {
      65 => UpArrow
      66 => DownArrow
      67 => RightArrow
      68 => LeftArrow
      70 => End
      72 => Home
      _ => Escape
    }
    return ConsoleKeyInfo::new('\u0000', key, shift, alt, control)
  }

  ConsoleKeyInfo::new('\u001b', Escape, false, false, false)
}

///|
fn decode_csi_modifier(mod_code : Int) -> (Bool, Bool, Bool) {
  let shift = mod_code is (50 | 52 | 54 | 56)
  let alt = mod_code is (51 | 52 | 55 | 56)
  let control = mod_code is (53 | 54 | 55 | 56)
  (shift, alt, control)
}

///|
pub fn read_line() -> String {
  if is_input_redirected() {
    abort("Console.ReadLine requires interactive stdin")
  }
  let _ = @ffi.init_terminal()
  let left : Array[Char] = []
  let right : Array[Char] = []
  while true {
    let key_info = read_key_raw(true)
    match key_info.key {
      Enter => {
        if !is_output_redirected() {
          write_mono("\n") |> ignore
        }
        let line = line_from_buffers(left, right)
        @ffi.uninit_terminal()
        return line
      }
      Backspace => if left.pop() is Some(_) { render_line(left, right) }
      Delete => if right.pop() is Some(_) { render_line(left, right) }
      LeftArrow =>
        if left.pop() is Some(ch) {
          right.push(ch)
          render_line(left, right)
        }
      RightArrow =>
        if right.pop() is Some(ch) {
          left.push(ch)
          render_line(left, right)
        }
      Home => {
        let mut changed = false
        while left.pop() is Some(ch) {
          right.push(ch)
          changed = true
        }
        if changed {
          render_line(left, right)
        }
      }
      End => {
        let mut changed = false
        while right.pop() is Some(ch) {
          left.push(ch)
          changed = true
        }
        if changed {
          render_line(left, right)
        }
      }
      _ => {
        let ch = key_info.key_char
        if !ch.is_control() {
          left.push(ch)
          render_line(left, right)
        }
      }
    }
  }
  let line = line_from_buffers(left, right)
  @ffi.uninit_terminal()
  line
}

///|
fn line_from_buffers(left : Array[Char], right : Array[Char]) -> String {
  let chars = Array::new(capacity=left.length() + right.length())
  chars.append(left)
  right.rev_each(ch => chars.push(ch))
  String::from_array(chars)
}

///|
fn render_line(left : Array[Char], right : Array[Char]) -> Unit {
  if is_output_redirected() {
    return
  }
  write_mono("\r") |> ignore
  write_mono(line_from_buffers(left, right)) |> ignore
  write_mono("\u{1b}[K") |> ignore
  if right.length() > 0 {
    move_cursor_left(right.length())
  }
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
      return -1
    }
  }
  -1
}

///|
fn read_escape_response() -> Array[Byte]? {
  let bytes : Array[Byte] = []
  let mut count = 0
  while count < 64 {
    let ch = read_byte_blocking()
    if ch < 0 {
      return None
    }
    bytes.push(ch.to_byte())
    if ch == 82 {
      return Some(bytes)
    }
    count = count + 1
  }
  None
}

///|
fn parse_cursor_report(bytes : Array[Byte]) -> (Int, Int)? {
  if bytes.length() < 6 {
    return None
  }
  if bytes[0].to_int() != 27 || bytes[1].to_int() != 91 {
    return None
  }

  let mut i = 2
  let mut row = 0
  let mut has_row = false
  while i < bytes.length() {
    let ch = bytes[i].to_int()
    if ch >= 48 && ch <= 57 {
      row = row * 10 + (ch - 48)
      has_row = true
      i = i + 1
      continue
    }
    if ch == 59 {
      i = i + 1
      break
    }
    return None
  }

  if !has_row || row <= 0 || i >= bytes.length() {
    return None
  }

  let mut col = 0
  let mut has_col = false
  while i < bytes.length() {
    let ch = bytes[i].to_int()
    if ch >= 48 && ch <= 57 {
      col = col * 10 + (ch - 48)
      has_col = true
      i = i + 1
      continue
    }
    if ch == 82 {
      if !has_col || col <= 0 {
        return None
      }
      return Some((col - 1, row - 1))
    }
    return None
  }
  None
}

///|
fn is_utf8_continuation(b : Int) -> Bool {
  b >= 128 && b <= 191
}

///|
fn read_utf8_char(first : Int) -> Char {
  if first <= 127 {
    return first.unsafe_to_char()
  }

  if first >= 194 && first <= 223 {
    let b2 = read_byte_blocking()
    if !is_utf8_continuation(b2) {
      return '\u{FFFD}'
    }
    let code = ((first & 0x1F) << 6) | (b2 & 0x3F)
    return code.unsafe_to_char()
  }

  if first >= 224 && first <= 239 {
    let b2 = read_byte_blocking()
    let b3 = read_byte_blocking()
    if !is_utf8_continuation(b2) || !is_utf8_continuation(b3) {
      return '\u{FFFD}'
    }
    let code = ((first & 0x0F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F)
    return code.unsafe_to_char()
  }

  if first >= 240 && first <= 244 {
    let b2 = read_byte_blocking()
    let b3 = read_byte_blocking()
    let b4 = read_byte_blocking()
    if !is_utf8_continuation(b2) ||
      !is_utf8_continuation(b3) ||
      !is_utf8_continuation(b4) {
      return '\u{FFFD}'
    }
    let code = ((first & 0x07) << 18) |
      ((b2 & 0x3F) << 12) |
      ((b3 & 0x3F) << 6) |
      (b4 & 0x3F)
    return code.unsafe_to_char()
  }

  '\u{FFFD}'
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

///|
fn ConsoleKey::from_csi_tilde_number(n : Int) -> ConsoleKey {
  match n {
    1 => Home
    2 => Insert
    3 => Delete
    4 => End
    5 => PageUp
    6 => PageDown
    15 => F5
    17 => F6
    18 => F7
    19 => F8
    20 => F9
    21 => F10
    23 => F11
    24 => F12
    _ => Escape
  }
}
