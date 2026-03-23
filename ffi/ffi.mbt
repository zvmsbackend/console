// ffi.mbt - FFI declarations for console native functions

///|
#external
pub(all) type StdHandle

///|
pub(all) struct WinSize {
  row : UInt
  col : UInt
  x_pixel : UInt
  y_pixel : UInt
}

// === Unix FFI: private externs + small public facade ===

///|
extern "c" fn c_console_isatty(fd : Int) -> Bool = "console_isatty"

///|
#borrow(buffer)
extern "c" fn c_console_write(fd : Int, buffer : Bytes, size : Int) -> Int = "console_write"

///|
extern "c" fn c_console_get_window_width() -> Int = "console_get_window_width"

///|
extern "c" fn c_console_get_window_height() -> Int = "console_get_window_height"

///|
extern "c" fn c_console_init_terminal() -> Int = "console_init_terminal"

///|
extern "c" fn c_console_uninit_terminal() = "console_uninit_terminal"

///|
#borrow(buffer)
extern "c" fn c_console_read_stdin(buffer : Bytes, size : Int) -> Int = "console_read_stdin"

///|
extern "c" fn c_console_stdin_ready() -> Bool = "console_stdin_ready"

///|
extern "c" fn c_console_get_signal_break() -> Int = "console_get_signal_break"

///|
extern "c" fn c_console_set_signal_break(enable : Int) -> Int = "console_set_signal_break"

///|
extern "c" fn c_console_set_cursor_position(left : Int, top : Int) -> Int = "console_set_cursor_position"

///|
extern "c" fn c_console_get_cursor_left() -> Int = "console_get_cursor_left"

///|
extern "c" fn c_console_get_cursor_top() -> Int = "console_get_cursor_top"

///|
extern "c" fn c_console_clear_screen() -> Int = "console_clear_screen"

///|
extern "c" fn c_console_set_foreground_color(color : Int) -> Int = "console_set_foreground_color"

///|
extern "c" fn c_console_set_background_color(color : Int) -> Int = "console_set_background_color"

///|
extern "c" fn c_console_get_foreground_color() -> Int = "console_get_foreground_color"

///|
extern "c" fn c_console_get_background_color() -> Int = "console_get_background_color"

///|
extern "c" fn c_console_reset_colors() -> Int = "console_reset_colors"

///|
extern "c" fn c_console_get_buffer_width() -> Int = "console_get_buffer_width"

///|
extern "c" fn c_console_get_buffer_height() -> Int = "console_get_buffer_height"

///|
extern "c" fn c_console_get_largest_window_width() -> Int = "console_get_largest_window_width"

///|
extern "c" fn c_console_get_largest_window_height() -> Int = "console_get_largest_window_height"

///|
extern "c" fn c_console_get_window_left() -> Int = "console_get_window_left"

///|
extern "c" fn c_console_get_window_top() -> Int = "console_get_window_top"

///|
extern "c" fn c_console_set_window_position(left : Int, top : Int) -> Int = "console_set_window_position"

///|
extern "c" fn c_console_set_window_size(width : Int, height : Int) -> Int = "console_set_window_size"

///|
extern "c" fn c_console_set_buffer_size(width : Int, height : Int) -> Int = "console_set_buffer_size"

///|
extern "c" fn c_console_beep_tone(frequency : Int, duration_ms : Int) -> Int = "console_beep_tone"

///|
extern "c" fn c_console_get_title() -> Bytes = "console_get_title"

///|
#borrow(title)
extern "c" fn c_console_set_title(title : Bytes) -> Int = "console_set_title"

///|
extern "c" fn c_console_get_cursor_size() -> Int = "console_get_cursor_size"

///|
extern "c" fn c_console_set_cursor_size(size : Int) -> Int = "console_set_cursor_size"

///|
extern "c" fn c_console_read_key_event() -> Int = "console_read_key_event"

///|
extern "c" fn c_console_last_key_char() -> Int = "console_last_key_char"

///|
extern "c" fn c_console_last_key_code() -> Int = "console_last_key_code"

///|
extern "c" fn c_console_last_key_modifiers() -> Int = "console_last_key_modifiers"

///|
extern "c" fn c_console_install_cancel_handlers(write_fd : Int) -> Int = "console_install_cancel_handlers"

///|
extern "c" fn c_console_restore_cancel_handlers() -> Int = "console_restore_cancel_handlers"

///|
extern "c" fn c_console_raise_default_signal(signum : Int) -> Int = "console_raise_default_signal"

///|
extern "c" fn c_console_take_pending_signal() -> Int = "console_take_pending_signal"

///|

///|
pub fn isatty(fd : Int) -> Bool {
  c_console_isatty(fd)
}

///|
pub fn write_fd(fd : Int, buffer : Bytes, size : Int) -> Int {
  c_console_write(fd, buffer, size)
}

///|
pub fn get_window_width() -> Int {
  c_console_get_window_width()
}

///|
pub fn get_window_height() -> Int {
  c_console_get_window_height()
}

///|
pub fn init_terminal() -> Int {
  c_console_init_terminal()
}

///|
pub fn uninit_terminal() -> Unit {
  c_console_uninit_terminal()
}

///|
pub fn read_stdin(buffer : Bytes, size : Int) -> Int {
  c_console_read_stdin(buffer, size)
}

///|
pub fn stdin_ready() -> Bool {
  c_console_stdin_ready()
}

///|
pub fn get_signal_break() -> Int {
  c_console_get_signal_break()
}

///|
pub fn set_signal_break(enable : Int) -> Int {
  c_console_set_signal_break(enable)
}

///|
pub fn set_cursor_position(left : Int, top : Int) -> Int {
  c_console_set_cursor_position(left, top)
}

///|
pub fn get_cursor_left() -> Int {
  c_console_get_cursor_left()
}

///|
pub fn get_cursor_top() -> Int {
  c_console_get_cursor_top()
}

///|
pub fn clear_screen() -> Int {
  c_console_clear_screen()
}

///|
pub fn set_foreground_color(color : Int) -> Int {
  c_console_set_foreground_color(color)
}

///|
pub fn set_background_color(color : Int) -> Int {
  c_console_set_background_color(color)
}

///|
pub fn get_foreground_color() -> Int {
  c_console_get_foreground_color()
}

///|
pub fn get_background_color() -> Int {
  c_console_get_background_color()
}

///|
pub fn reset_colors() -> Int {
  c_console_reset_colors()
}

///|
pub fn get_buffer_width() -> Int {
  c_console_get_buffer_width()
}

///|
pub fn get_buffer_height() -> Int {
  c_console_get_buffer_height()
}

///|
pub fn get_largest_window_width() -> Int {
  c_console_get_largest_window_width()
}

///|
pub fn get_largest_window_height() -> Int {
  c_console_get_largest_window_height()
}

///|
pub fn get_window_left() -> Int {
  c_console_get_window_left()
}

///|
pub fn get_window_top() -> Int {
  c_console_get_window_top()
}

///|
pub fn set_window_position(left : Int, top : Int) -> Int {
  c_console_set_window_position(left, top)
}

///|
pub fn set_window_size(width : Int, height : Int) -> Int {
  c_console_set_window_size(width, height)
}

///|
pub fn set_buffer_size(width : Int, height : Int) -> Int {
  c_console_set_buffer_size(width, height)
}

///|
pub fn beep_tone(frequency : Int, duration_ms : Int) -> Int {
  c_console_beep_tone(frequency, duration_ms)
}

///|
pub fn get_title() -> Bytes {
  c_console_get_title()
}

///|
pub fn set_title(title : Bytes) -> Int {
  c_console_set_title(title)
}

///|
pub fn get_cursor_size() -> Int {
  c_console_get_cursor_size()
}

///|
pub fn set_cursor_size(size : Int) -> Int {
  c_console_set_cursor_size(size)
}

///|
pub fn read_key_event() -> Int {
  c_console_read_key_event()
}

///|
pub fn last_key_char() -> Int {
  c_console_last_key_char()
}

///|
pub fn last_key_code() -> Int {
  c_console_last_key_code()
}

///|
pub fn last_key_modifiers() -> Int {
  c_console_last_key_modifiers()
}

///|
pub fn install_cancel_handlers(write_fd : Int) -> Int {
  c_console_install_cancel_handlers(write_fd)
}

///|
pub fn restore_cancel_handlers() -> Int {
  c_console_restore_cancel_handlers()
}

///|
pub fn raise_default_signal(signum : Int) -> Int {
  c_console_raise_default_signal(signum)
}

///|
pub fn take_pending_signal() -> Int {
  c_console_take_pending_signal()
}

///|
