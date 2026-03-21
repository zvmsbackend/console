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
