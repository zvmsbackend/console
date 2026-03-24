///|
fn print_usage() -> Unit {
  @console.write_line("usage: linux_console_async <scenario>")
  @console.write_line("scenarios:")
  @console.write_line("  async-cancel-handled-read-key")
  @console.write_line("  async-cancel-unhandled-read-key")
  @console.write_line("  async-cancel-handled-wait-signal")
  @console.write_line("  async-cancel-unhandled-wait-signal")
}

///|
async fn run_async_cancel_handled_read_key() -> Unit {
  @async.with_task_group(fn(tg) {
    tg.spawn_bg(no_wait=true, async fn() {
      @console.start_async_cancel_dispatcher()
    })
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
  })
}

///|
async fn run_async_cancel_unhandled_read_key() -> Unit {
  @async.with_task_group(fn(tg) {
    tg.spawn_bg(no_wait=true, async fn() {
      @console.start_async_cancel_dispatcher()
    })
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
  })
}

///|
async fn run_async_cancel_handled_wait_signal() -> Unit {
  let handled : Ref[Bool] = @ref.new(false)
  @async.with_task_group(async fn(tg) {
    tg.spawn_bg(no_wait=true, async fn() {
      @console.start_async_cancel_dispatcher()
    })
    @console.add_cancel_key_press_handler(fn(key) {
      match key {
        ControlC => @console.write_line("HANDLED=ControlC")
        ControlBreak => @console.write_line("HANDLED=ControlBreak")
      }
      handled.val = true
      true
    })
    |> ignore
    @console.write_line("READY")
    while !handled.val {
      @async.pause()
    }
    @console.write_line("AFTER_SIGNAL")
  })
}

///|
async fn run_async_cancel_unhandled_wait_signal() -> Unit {
  @async.with_task_group(async fn(tg) {
    tg.spawn_bg(no_wait=true, async fn() {
      @console.start_async_cancel_dispatcher()
    })
    @console.add_cancel_key_press_handler(fn(key) {
      match key {
        ControlC => @console.write_line("UNHANDLED=ControlC")
        ControlBreak => @console.write_line("UNHANDLED=ControlBreak")
      }
      false
    })
    |> ignore
    @console.write_line("READY")
    while true {
      @async.pause()
    }
  })
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
    "async-cancel-handled-wait-signal" => run_async_cancel_handled_wait_signal()
    "async-cancel-unhandled-wait-signal" =>
      run_async_cancel_unhandled_wait_signal()
    _ => print_usage()
  }
}
