///|
fn usage() -> Unit {
  @console.write_line("usage: ctrl_event_demo <handled|unhandled>")
}

///|
fn run_handled() -> Unit {
  let handled : Ref[Bool] = @ref.new(false)
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
    @console.key_available() |> ignore
  }
  @console.write_line("EXIT_OK")
}

///|
fn run_unhandled() -> Unit {
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
    @console.key_available() |> ignore
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    usage()
    return
  }
  match args[1] {
    "handled" => run_handled()
    "unhandled" => run_unhandled()
    _ => usage()
  }
}
