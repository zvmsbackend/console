// console_windows.mbt - Windows console implementation

///|
#cfg(platform="windows")
const STDIN_FD = 0

///|
#cfg(platform="windows")
const STDOUT_FS = 1

///|
#cfg(platform="windows")
const STDERR_FD = 2

///|
#cfg(platform="windows")
let cancel_handler_next_id : Ref[Int] = @ref.new(1)

///|
#cfg(platform="windows")
let cancel_handlers : Array[(Int, (ConsoleSpecialKey) -> Bool)] = []

///|
#cfg(platform="windows")
let cancel_handlers_installed : Ref[Bool] = @ref.new(false)

///|
#cfg(platform="windows")
let cancel_dispatcher_started : Ref[Bool] = @ref.new(false)

///|
#cfg(platform="windows")
let tracked_foreground_color : Ref[ConsoleColor?] = @ref.new(None)

///|
#cfg(platform="windows")
let tracked_background_color : Ref[ConsoleColor?] = @ref.new(None)

///|
#cfg(platform="windows")
let cached_cursor_left : Ref[Int] = @ref.new(0)

///|
#cfg(platform="windows")
let cached_cursor_top : Ref[Int] = @ref.new(0)

///|
#cfg(platform="windows")
let cached_cursor_valid : Ref[Bool] = @ref.new(false)

///|
#cfg(platform="windows")
const SHORT_MAX = 32767

///|
#cfg(platform="windows")
let skip_lf_after_cr_in_redirected : Ref[Bool] = @ref.new(false)

///|
#cfg(platform="windows")
/// Registers a Ctrl+C/Ctrl+Break handler and returns a handler id.
pub fn add_cancel_key_press_handler(
  handler : (ConsoleSpecialKey) -> Bool,
) -> Int {
  if !cancel_handlers_installed.val {
    if @ffi.install_cancel_handlers(-1) != 0 {
      abort("failed to install cancel signal handlers")
    }
    cancel_handlers_installed.val = true
  }
  let id = cancel_handler_next_id.val
  cancel_handler_next_id.val = id + 1
  cancel_handlers.push((id, handler))
  id
}

///|
#cfg(platform="windows")
/// Unregisters a previously registered cancel-key handler.
pub fn remove_cancel_key_press_handler(handler_id : Int) -> Unit {
  let before = cancel_handlers.length()
  cancel_handlers.retain(entry => entry.0 != handler_id)
  if before != cancel_handlers.length() && cancel_handlers.length() == 0 {
    if @ffi.restore_cancel_handlers() != 0 {
      abort("failed to restore cancel signal handlers")
    }
    cancel_handlers_installed.val = false
    cancel_dispatcher_started.val = false
  }
}

///|
#cfg(platform="windows")
fn signal_to_special_key(signum : Int) -> ConsoleSpecialKey? {
  match signum {
    2 => Some(ControlC)
    3 => Some(ControlBreak)
    _ => None
  }
}

///|
#cfg(platform="windows")
fn dispatch_cancel_signal(signum : Int) -> Unit {
  if signum <= 0 {
    return
  }
  if signal_to_special_key(signum) is Some(key) {
    let mut canceled = false
    for entry in cancel_handlers {
      let handler = entry.1
      if handler(key) {
        canceled = true
      }
    }
    if !canceled {
      if @ffi.raise_default_signal(signum) != 0 {
        abort("failed to dispatch default cancel signal behavior")
      }
    }
  }
}

///|
#cfg(platform="windows")
fn dispatch_pending_cancel_signal_sync() -> Unit {
  let signum = @ffi.take_pending_signal()
  if signum > 0 {
    dispatch_cancel_signal(signum)
  }
}

///|
#cfg(platform="windows")
/// Runs cooperative async cancel-signal polling in the current async runtime.
pub async fn start_async_cancel_dispatcher() -> Unit {
  if !cancel_handlers_installed.val {
    if @ffi.install_cancel_handlers(-1) != 0 {
      abort("failed to install cancel signal handlers")
    }
    cancel_handlers_installed.val = true
  }
  cancel_dispatcher_started.val = true
  while cancel_dispatcher_started.val {
    dispatch_pending_cancel_signal_sync()
    @async.pause()
  }
}

///|
#cfg(platform="windows")
/// Returns true when stdin is redirected instead of attached to a terminal.
pub fn is_input_redirected() -> Bool {
  !@ffi.isatty(STDIN_FD)
}

///|
#cfg(platform="windows")
/// Returns true when stdout is redirected instead of attached to a terminal.
pub fn is_output_redirected() -> Bool {
  !@ffi.isatty(STDOUT_FS)
}

///|
#cfg(platform="windows")
/// Returns true when stderr is redirected instead of attached to a terminal.
pub fn is_error_redirected() -> Bool {
  !@ffi.isatty(STDERR_FD)
}

///|
#cfg(platform="windows")
fn write_mono(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDOUT_FS, bytes, bytes.length())
  if n < 0 {
    abort("console write failed")
  }
  update_cached_cursor_after_write(s)
  n
}

///|
#cfg(platform="windows")
fn write_line_mono(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDOUT_FS, bytes, bytes.length())
  @ffi.write_fd(STDOUT_FS, @utf8.encode("\n"), 1) |> ignore
  n
}

///|
#cfg(platform="windows")
/// Writes a string to standard error without a trailing newline.
pub fn error_write(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDERR_FD, bytes, bytes.length())
  if n < 0 {
    abort("console error write failed")
  }
  n
}

///|
#cfg(platform="windows")
/// Writes a string to standard error followed by a newline.
pub fn error_write_line(s : String) -> Int {
  let bytes = @utf8.encode(s)
  let n = @ffi.write_fd(STDERR_FD, bytes, bytes.length())
  @ffi.write_fd(STDERR_FD, @utf8.encode("\n"), 1) |> ignore
  n
}

///|
#cfg(platform="windows")
/// Returns the current console window width and height as a pair.
pub fn get_window_size() -> (Int, Int) {
  let width = @ffi.get_window_width()
  let height = @ffi.get_window_height()
  (width, height)
}

///|
#cfg(platform="windows")
/// Returns the current console window width in columns.
pub fn get_window_width() -> Int {
  @ffi.get_window_width()
}

///|
#cfg(platform="windows")
/// Returns the current console window height in rows.
pub fn get_window_height() -> Int {
  @ffi.get_window_height()
}

///|
#cfg(platform="windows")
/// Returns the current screen buffer width.
pub fn get_buffer_width() -> Int {
  let w = @ffi.get_buffer_width()
  if w > 0 {
    w
  } else {
    get_window_width()
  }
}

///|
#cfg(platform="windows")
/// Returns the current screen buffer height.
pub fn get_buffer_height() -> Int {
  let h = @ffi.get_buffer_height()
  if h > 0 {
    h
  } else {
    get_window_height()
  }
}

///|
#cfg(platform="windows")
/// Returns the maximum window width supported by the current console.
pub fn get_largest_window_width() -> Int {
  let w = @ffi.get_largest_window_width()
  if w > 0 {
    w
  } else {
    get_window_width()
  }
}

///|
#cfg(platform="windows")
/// Returns the maximum window height supported by the current console.
pub fn get_largest_window_height() -> Int {
  let h = @ffi.get_largest_window_height()
  if h > 0 {
    h
  } else {
    get_window_height()
  }
}

///|
#cfg(platform="windows")
/// Returns the window left offset inside the screen buffer.
pub fn get_window_left() -> Int {
  let left = @ffi.get_window_left()
  if left >= 0 {
    left
  } else {
    0
  }
}

///|
#cfg(platform="windows")
/// Returns the window top offset inside the screen buffer.
pub fn get_window_top() -> Int {
  let top = @ffi.get_window_top()
  if top >= 0 {
    top
  } else {
    0
  }
}

///|
#cfg(platform="windows")
/// Moves the console window to the given left/top position.
pub fn set_window_position(left : Int, top : Int) -> Unit {
  let width = get_window_width()
  let height = get_window_height()
  let buffer_width = get_buffer_width()
  let buffer_height = get_buffer_height()

  if !window_position_in_bounds(
      left, top, width, height, buffer_width, buffer_height,
    ) {
    abort("left/top must be non-negative")
  }
  if @ffi.set_window_position(left, top) != 0 {
    abort("failed to set window position")
  }
}

///|
#cfg(platform="windows")
/// Sets the console window size in columns and rows.
pub fn set_window_size(width : Int, height : Int) -> Unit {
  if is_output_redirected() {
    abort("set_window_size requires interactive stdout")
  }
  if width <= 0 || height <= 0 {
    abort("width/height must be positive")
  }
  let left = get_window_left()
  let top = get_window_top()
  let old_buffer_width = get_buffer_width()
  let old_buffer_height = get_buffer_height()

  if left >= SHORT_MAX - width {
    abort("width out of range")
  }
  if top >= SHORT_MAX - height {
    abort("height out of range")
  }

  let needed_buffer_width = if old_buffer_width < left + width {
    left + width
  } else {
    old_buffer_width
  }
  let needed_buffer_height = if old_buffer_height < top + height {
    top + height
  } else {
    old_buffer_height
  }

  let resized_buffer = needed_buffer_width != old_buffer_width ||
    needed_buffer_height != old_buffer_height

  if resized_buffer {
    if @ffi.set_buffer_size(needed_buffer_width, needed_buffer_height) != 0 {
      abort("failed to resize buffer for window size")
    }
  }

  if @ffi.set_window_size(width, height) != 0 {
    if resized_buffer {
      @ffi.set_buffer_size(old_buffer_width, old_buffer_height) |> ignore
    }
    let largest_w = get_largest_window_width()
    let largest_h = get_largest_window_height()
    if width > largest_w {
      abort("width exceeds largest window width")
    }
    if height > largest_h {
      abort("height exceeds largest window height")
    }
    abort("failed to set window size")
  }
}

///|
#cfg(platform="windows")
/// Sets the screen buffer size in columns and rows.
pub fn set_buffer_size(width : Int, height : Int) -> Unit {
  if !buffer_size_in_bounds(
      width,
      height,
      get_window_left(),
      get_window_top(),
      get_window_width(),
      get_window_height(),
    ) {
    abort("width/height must be positive")
  }
  if @ffi.set_buffer_size(width, height) != 0 {
    abort("failed to set buffer size")
  }
}

///|
#cfg(platform="windows")
fn window_position_in_bounds(
  left : Int,
  top : Int,
  width : Int,
  height : Int,
  buffer_width : Int,
  buffer_height : Int,
) -> Bool {
  let new_right = left + width - 1
  let new_bottom = top + height - 1
  left >= 0 &&
  new_right >= left &&
  new_right <= buffer_width - 1 &&
  top >= 0 &&
  new_bottom >= top &&
  new_bottom <= buffer_height - 1
}

///|
#cfg(platform="windows")
fn buffer_size_in_bounds(
  width : Int,
  height : Int,
  window_left : Int,
  window_top : Int,
  window_width : Int,
  window_height : Int,
) -> Bool {
  if width <= 0 || height <= 0 || width >= SHORT_MAX || height >= SHORT_MAX {
    return false
  }
  let min_width = window_left + window_width
  let min_height = window_top + window_height
  width >= min_width && height >= min_height
}

///|
#cfg(platform="windows")
/// Sets the console window width while preserving current height.
pub fn set_window_width(width : Int) -> Unit {
  set_window_size(width, get_window_height())
}

///|
#cfg(platform="windows")
/// Sets the console window height while preserving current width.
pub fn set_window_height(height : Int) -> Unit {
  set_window_size(get_window_width(), height)
}

///|
#cfg(platform="windows")
/// Sets the screen buffer width while preserving current height.
pub fn set_buffer_width(width : Int) -> Unit {
  set_buffer_size(width, get_buffer_height())
}

///|
#cfg(platform="windows")
/// Sets the screen buffer height while preserving current width.
pub fn set_buffer_height(height : Int) -> Unit {
  set_buffer_size(get_buffer_width(), height)
}

///|
#cfg(platform="windows")
/// Clears the console and moves the cursor to the home position.
pub fn clear() -> Unit {
  if !is_output_redirected() {
    if @ffi.clear_screen() != 0 {
      write_mono("\u{1b}[2J\u{1b}[H") |> ignore
    }
    cache_cursor_position(0, 0)
  }
}

///|
#cfg(platform="windows")
/// Sets the text foreground color.
pub fn set_foreground_color(color : ConsoleColor) -> Unit {
  if @ffi.set_foreground_color(color.to_int()) == 0 {
    tracked_foreground_color.val = Some(color)
    return
  }
  tracked_foreground_color.val = Some(color)
  if !is_output_redirected() {
    let cmd = "\u{1b}[3\{color.to_int()}m"
    write_mono(cmd) |> ignore
  }
}

///|
#cfg(platform="windows")
/// Gets the currently tracked foreground color if available.
pub fn get_foreground_color() -> ConsoleColor? {
  let c = @ffi.get_foreground_color()
  if c >= 0 {
    return Some(console_color_from_int(c))
  }
  tracked_foreground_color.val
}

///|
#cfg(platform="windows")
/// Sets the text background color.
pub fn set_background_color(color : ConsoleColor) -> Unit {
  if @ffi.set_background_color(color.to_int()) == 0 {
    tracked_background_color.val = Some(color)
    return
  }
  tracked_background_color.val = Some(color)
  if !is_output_redirected() {
    let cmd = "\u{1b}[4\{color.to_int()}m"
    write_mono(cmd) |> ignore
  }
}

///|
#cfg(platform="windows")
/// Gets the currently tracked background color if available.
pub fn get_background_color() -> ConsoleColor? {
  let c = @ffi.get_background_color()
  if c >= 0 {
    return Some(console_color_from_int(c))
  }
  tracked_background_color.val
}

///|
#cfg(platform="windows")
/// Resets foreground and background colors to defaults.
pub fn reset_color() -> Unit {
  if @ffi.reset_colors() == 0 {
    tracked_foreground_color.val = None
    tracked_background_color.val = None
    return
  }
  tracked_foreground_color.val = None
  tracked_background_color.val = None
  if !is_output_redirected() {
    write_mono("\u{1b}[0m") |> ignore
  }
}

///|
#cfg(platform="windows")
/// Emits a simple bell sound when supported by the terminal.
pub fn beep() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{07}") |> ignore
  }
}

///|
#cfg(platform="windows")
/// Emits a tone with frequency and duration (Windows only).
pub fn beep_tone(frequency : Int, duration_ms : Int) -> Unit {
  if frequency < 37 || frequency > 32767 {
    abort("frequency out of range")
  }
  if duration_ms <= 0 {
    abort("duration must be positive")
  }
  if @ffi.beep_tone(frequency, duration_ms) != 0 {
    abort("failed to beep with frequency/duration")
  }
}

///|
#cfg(platform="windows")
/// Gets the console window title (Windows only).
pub fn get_title() -> String {
  @utf8.decode_lossy(@ffi.get_title())
}

///|
#cfg(platform="windows")
/// Sets the console window title (Windows only).
pub fn set_title(title : String) -> Unit {
  if @ffi.set_title(@utf8.encode(title)) != 0 {
    abort("failed to set console title")
  }
}

///|
#cfg(platform="windows")
/// Gets the cursor size percentage (Windows only).
pub fn get_cursor_size() -> Int {
  let size = @ffi.get_cursor_size()
  if size < 0 {
    abort("failed to get cursor size")
  }
  size
}

///|
#cfg(platform="windows")
/// Sets the cursor size percentage in range 1..100 (Windows only).
pub fn set_cursor_size(size : Int) -> Unit {
  if size < 1 || size > 100 {
    abort("cursor size out of range")
  }
  if @ffi.set_cursor_size(size) != 0 {
    abort("failed to set cursor size")
  }
}

///|
#cfg(platform="windows")
/// Hides the console cursor.
pub fn hide_cursor() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[?25l") |> ignore
  }
}

///|
#cfg(platform="windows")
/// Shows or hides the console cursor.
pub fn set_cursor_visible(visible : Bool) -> Unit {
  if visible {
    show_cursor()
  } else {
    hide_cursor()
  }
}

///|
#cfg(platform="windows")
/// Shows the console cursor.
pub fn show_cursor() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[?25h") |> ignore
  }
}

///|
#cfg(platform="windows")
/// Gets whether Ctrl+C is treated as input instead of interrupt.
pub fn get_treat_control_c_as_input() -> Bool {
  if is_input_redirected() {
    return false
  }
  @ffi.get_signal_break() == 0
}

///|
#cfg(platform="windows")
/// Configures whether Ctrl+C is treated as input instead of interrupt.
pub fn set_treat_control_c_as_input(value : Bool) -> Unit {
  if !is_input_redirected() {
    let enable_signal_break = if value { 0 } else { 1 }
    if @ffi.set_signal_break(enable_signal_break) != 0 {
      abort("failed to set signal break mode")
    }
  }
}

///|
#cfg(platform="windows")
/// Clears the current line and returns the cursor to column 0.
pub fn clear_line() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[2K") |> ignore
  }
}

///|
#cfg(platform="windows")
/// Clears from the current cursor position to end of line.
pub fn clear_to_end_of_line() -> Unit {
  if !is_output_redirected() {
    write_mono("\u{1b}[K") |> ignore
  }
}

///|
#cfg(platform="windows")
/// Moves the cursor up by the given number of lines.
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
#cfg(platform="windows")
/// Moves the cursor down by the given number of lines.
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
#cfg(platform="windows")
/// Moves the cursor right by the given number of columns.
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
#cfg(platform="windows")
/// Moves the cursor left by the given number of columns.
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
#cfg(platform="windows")
/// Sets the cursor position using zero-based left/top coordinates.
pub fn set_cursor_position(left : Int, top : Int) -> Unit {
  if left < 0 || top < 0 {
    abort("left/top must be non-negative")
  }
  if !is_output_redirected() {
    if @ffi.set_cursor_position(left, top) != 0 {
      let cmd = "\u{1b}[\{top + 1};\{left + 1}H"
      write_mono(cmd) |> ignore
    }
    cache_cursor_position(left, top)
  }
}

///|
#cfg(platform="windows")
/// Gets the current cursor position as zero-based left/top coordinates.
pub fn get_cursor_position() -> (Int, Int) {
  if is_input_redirected() || is_output_redirected() {
    return (0, 0)
  }

  if cached_cursor_valid.val {
    return (cached_cursor_left.val, cached_cursor_top.val)
  }

  let left = @ffi.get_cursor_left()
  let top = @ffi.get_cursor_top()
  if left >= 0 && top >= 0 {
    cache_cursor_position(left, top)
    return (left, top)
  }

  if @ffi.init_terminal() != 0 {
    return (0, 0)
  }

  write_mono("\u{1b}[6n") |> ignore
  let report = read_escape_response()
  @ffi.uninit_terminal()

  if report is Some(bytes) {
    if parse_cursor_report(bytes) is Some((left, top)) {
      cache_cursor_position(left, top)
      return (left, top)
    }
  }
  invalidate_cached_cursor_position()
  (0, 0)
}

///|
#cfg(platform="windows")
/// Gets the current zero-based cursor column.
pub fn get_cursor_left() -> Int {
  let (left, _) = get_cursor_position()
  left
}

///|
#cfg(platform="windows")
/// Gets the current zero-based cursor row.
pub fn get_cursor_top() -> Int {
  let (_, top) = get_cursor_position()
  top
}

///|
#cfg(platform="windows")
/// Returns true when input is available to read without blocking.
pub fn key_available() -> Bool {
  dispatch_pending_cancel_signal_sync()
  @ffi.stdin_ready()
}

///|
#cfg(platform="windows")
/// Reads the next Unicode scalar value from console input or redirected input.
pub fn read() -> Int {
  dispatch_pending_cancel_signal_sync()
  if is_input_redirected() {
    return read_redirected_char()
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
#cfg(platform="windows")
/// Reads one key press and returns key plus modifier information.
pub fn read_key(intercept? : Bool = false) -> ConsoleKeyInfo {
  dispatch_pending_cancel_signal_sync()
  if is_input_redirected() {
    abort("Console.ReadKey requires interactive stdin")
  }
  let _ = @ffi.init_terminal()
  let info = read_key_raw(intercept)
  @ffi.uninit_terminal()
  info
}

///|
#cfg(platform="windows")
fn read_key_raw(intercept : Bool) -> ConsoleKeyInfo {
  if @ffi.read_key_event() != 0 {
    return ConsoleKeyInfo::new('\u0000', Space, false, false, false)
  }

  let char_code = @ffi.last_key_char()
  let key_code = @ffi.last_key_code()
  let mods = @ffi.last_key_modifiers()
  let shift = (mods & 1) != 0
  let alt = (mods & 2) != 0
  let control = (mods & 4) != 0

  let key = ConsoleKey::from_windows_vk(key_code)
  let key_char = if char_code > 0 {
    char_code.unsafe_to_char()
  } else {
    '\u0000'
  }

  if !intercept && char_code > 0 && !key_char.is_control() {
    write_mono(key_char.to_string()) |> ignore
  }

  ConsoleKeyInfo::new(key_char, key, shift, alt, control)
}

///|
#cfg(platform="windows")
/// Reads a line from input, excluding trailing newline characters.
pub fn read_line() -> String {
  dispatch_pending_cancel_signal_sync()
  if is_input_redirected() {
    return read_line_redirected()
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
#cfg(platform="windows")
fn line_from_buffers(left : Array[Char], right : Array[Char]) -> String {
  let chars = Array::new(capacity=left.length() + right.length())
  chars.append(left)
  right.rev_each(ch => chars.push(ch))
  String::from_array(chars)
}

///|
#cfg(platform="windows")
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
#cfg(platform="windows")
fn read_byte_blocking() -> Int {
  let buffer = Bytes::new(1)
  while true {
    dispatch_pending_cancel_signal_sync()
    let n = @ffi.read_stdin(buffer, 1)
    if n > 0 {
      dispatch_pending_cancel_signal_sync()
      return buffer[0].to_int()
    }
    if n < 0 {
      return -1
    }
  }
  -1
}

///|
#cfg(platform="windows")
fn read_redirected_byte() -> Int {
  let buffer = Bytes::new(1)
  while true {
    let n = @ffi.read_stdin(buffer, 1)
    if n > 0 {
      return buffer[0].to_int()
    }
    if n == 0 {
      return -1
    }
    if n < 0 {
      return -1
    }
  }
  -1
}

///|
#cfg(platform="windows")
fn read_redirected_byte_for_line() -> Int {
  while true {
    let ch = read_redirected_byte()
    if ch < 0 {
      return -1
    }
    if skip_lf_after_cr_in_redirected.val && ch == 10 {
      skip_lf_after_cr_in_redirected.val = false
      continue
    }
    skip_lf_after_cr_in_redirected.val = false
    return ch
  }
  -1
}

///|
#cfg(platform="windows")
fn read_redirected_char() -> Int {
  let first = read_redirected_byte()
  if first < 0 {
    return -1
  }
  if first <= 127 {
    return first
  }

  if first >= 194 && first <= 223 {
    let b2 = read_redirected_byte()
    if b2 < 0 || b2 < 128 || b2 > 191 {
      return 65533
    }
    return ((first & 0x1F) << 6) | (b2 & 0x3F)
  }

  if first >= 224 && first <= 239 {
    let b2 = read_redirected_byte()
    let b3 = read_redirected_byte()
    if b2 < 128 || b2 > 191 || b3 < 128 || b3 > 191 {
      return 65533
    }
    return ((first & 0x0F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F)
  }

  if first >= 240 && first <= 244 {
    let b2 = read_redirected_byte()
    let b3 = read_redirected_byte()
    let b4 = read_redirected_byte()
    if b2 < 128 || b2 > 191 || b3 < 128 || b3 > 191 || b4 < 128 || b4 > 191 {
      return 65533
    }
    return ((first & 0x07) << 18) |
      ((b2 & 0x3F) << 12) |
      ((b3 & 0x3F) << 6) |
      (b4 & 0x3F)
  }

  65533
}

///|
#cfg(platform="windows")
fn read_line_redirected() -> String {
  let bytes : Array[Byte] = []
  while true {
    let ch = read_redirected_byte_for_line()
    if ch < 0 {
      return @utf8.decode_lossy(Bytes::from_array(bytes))
    }
    if ch == 10 {
      return @utf8.decode_lossy(Bytes::from_array(bytes))
    }
    if ch == 13 {
      skip_lf_after_cr_in_redirected.val = true
      return @utf8.decode_lossy(Bytes::from_array(bytes))
    }
    bytes.push(ch.to_byte())
  }
  @utf8.decode_lossy(Bytes::from_array(bytes))
}

///|
#cfg(platform="windows")
fn invalidate_cached_cursor_position() -> Unit {
  cached_cursor_valid.val = false
}

///|
#cfg(platform="windows")
fn cache_cursor_position(left : Int, top : Int) -> Unit {
  cached_cursor_left.val = left
  cached_cursor_top.val = top
  cached_cursor_valid.val = true
}

///|
#cfg(platform="windows")
fn update_cached_cursor_after_write(s : String) -> Unit {
  if !cached_cursor_valid.val {
    return
  }

  let mut left = cached_cursor_left.val
  let mut top = cached_cursor_top.val
  let width = get_window_width()
  let height = get_window_height()

  for c in s {
    let code = c.to_int()
    if code == 27 {
      invalidate_cached_cursor_position()
      return
    }
    if code >= 32 && code < 127 {
      left = left + 1
      if left >= width {
        invalidate_cached_cursor_position()
        return
      }
      continue
    }
    if code == 13 {
      left = 0
      continue
    }
    if code == 10 {
      left = 0
      top = top + 1
      if top >= height {
        top = height - 1
      }
      continue
    }
    if code == 8 {
      if left > 0 {
        left = left - 1
      }
      continue
    }
  }

  cache_cursor_position(left, top)
}

///|
#cfg(platform="windows")
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
#cfg(platform="windows")
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
#cfg(platform="windows")
fn ConsoleKey::from_windows_vk(code : Int) -> ConsoleKey {
  match code {
    8 => Backspace
    9 => Tab
    13 => Enter
    27 => Escape
    32 => Space
    33 => PageUp
    34 => PageDown
    35 => End
    36 => Home
    37 => LeftArrow
    38 => UpArrow
    39 => RightArrow
    40 => DownArrow
    45 => Insert
    46 => Delete
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
    112 => F1
    113 => F2
    114 => F3
    115 => F4
    116 => F5
    117 => F6
    118 => F7
    119 => F8
    120 => F9
    121 => F10
    122 => F11
    123 => F12
    _ => Space
  }
}

///|
#cfg(platform="windows")
fn console_color_from_int(color : Int) -> ConsoleColor {
  match color {
    0 => Black
    1 => DarkBlue
    2 => DarkGreen
    3 => DarkCyan
    4 => DarkRed
    5 => DarkMagenta
    6 => DarkYellow
    7 => Gray
    8 => DarkGray
    9 => Blue
    10 => Green
    11 => Cyan
    12 => Red
    13 => Magenta
    14 => Yellow
    15 => White
    _ => White
  }
}
