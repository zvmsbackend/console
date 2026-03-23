///|
fn print_usage() -> Unit {
  @console.write_line("usage: linux_console_async <scenario>")
  @console.write_line("scenarios:")
  @console.write_line("  async-cancel-handled-read-key")
  @console.write_line("  async-cancel-unhandled-read-key")
}

///|
async fn run_async_cancel_handled_read_key() -> Unit {
  @console.start_async_cancel_dispatcher() |> ignore
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
async fn run_async_cancel_unhandled_read_key() -> Unit {
  @console.start_async_cancel_dispatcher() |> ignore
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
async fn main {
  let args = @env.args()
  if args.length() < 2 {
    print_usage()
    return
  }
  let scenario = args[1]
  match scenario {
    "async-cancel-handled-read-key" => run_async_cancel_handled_read_key()
    "async-cancel-unhandled-read-key" => run_async_cancel_unhandled_read_key()
    _ => print_usage()
  }
}
