///|
pub fn[T : Show] write(value : T) -> Unit {
  write_mono(value.to_string()) |> ignore
}

///|
pub fn[T : Show] write_line(value : T) -> Unit {
  write_line_mono(value.to_string()) |> ignore
}

///|
pub fn newline() -> Unit {
  write_line_mono("") |> ignore
}
