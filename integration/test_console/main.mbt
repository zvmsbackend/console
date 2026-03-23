///|
fn print_usage() -> Unit {
  @console.write_line("usage: linux_console <scenario>")
  @console.write_line("scenarios:")
  @console.write_line("  redirected-read-line-two")
  @console.write_line("  redirected-read-char-two")
  @console.write_line("  read-key")
  @console.write_line("  cancel-handled-read-key")
  @console.write_line("  cancel-unhandled-read-key")
  @console.write_line("  redirect-flags")
  @console.write_line("  window-size")
}

///|
fn run_redirected_read_line_two() -> Unit {
  let l1 = @console.read_line()
  let l2 = @console.read_line()
  @console.write_line("L1=\{l1}")
  @console.write_line("L2=\{l2}")
}

///|
fn run_redirected_read_char_two() -> Unit {
  let c1 = @console.read()
  let c2 = @console.read()
  @console.write_line("C1=\{c1}")
  @console.write_line("C2=\{c2}")
}

///|
fn run_read_key() -> Unit {
  let info = @console.read_key(intercept=true)
  @console.write_line(
    "KC=\{info.key_char.to_int()} K=\{info.key.to_int()} S=\{info.shift} A=\{info.alt} C=\{info.control}",
  )
}

///|
fn run_cancel_handled_read_key() -> Unit {
  @console.add_cancel_key_press_handler(fn(key) {
    match key {
      ControlC => @console.write_line("HANDLED=ControlC")
      ControlBreak => @console.write_line("HANDLED=ControlBreak")
    }
    true
  })
  |> ignore
  let info = @console.read_key(intercept=true)
  @console.write_line(
    "AFTER KC=\{info.key_char.to_int()} K=\{info.key.to_int()}",
  )
}

///|
fn run_cancel_unhandled_read_key() -> Unit {
  @console.add_cancel_key_press_handler(fn(key) {
    match key {
      ControlC => @console.write_line("UNHANDLED=ControlC")
      ControlBreak => @console.write_line("UNHANDLED=ControlBreak")
    }
    false
  })
  |> ignore
  @console.read_key(intercept=true) |> ignore
  @console.write_line("SHOULD_NOT_REACH")
}

///|
fn run_redirect_flags() -> Unit {
  @console.write_line("IN=\{@console.is_input_redirected()}")
  @console.write_line("OUT=\{@console.is_output_redirected()}")
  @console.write_line("ERR=\{@console.is_error_redirected()}")
}

///|
fn run_window_size() -> Unit {
  let (w, h) = @console.get_window_size()
  @console.write_line("W=\{w} H=\{h}")
}

///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    print_usage()
    return
  }
  match args[1] {
    "redirected-read-line-two" => run_redirected_read_line_two()
    "redirected-read-char-two" => run_redirected_read_char_two()
    "read-key" => run_read_key()
    "cancel-handled-read-key" => run_cancel_handled_read_key()
    "cancel-unhandled-read-key" => run_cancel_unhandled_read_key()
    "redirect-flags" => run_redirect_flags()
    "window-size" => run_window_size()
    _ => print_usage()
  }
}
