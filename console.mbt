///|
/// Writes a value to standard output without a trailing newline.
pub fn[T : Show] write(value : T) -> Unit {
  write_mono(value.to_string()) |> ignore
}

///|
/// Writes a value to standard output followed by a newline.
pub fn[T : Show] write_line(value : T) -> Unit {
  write_line_mono(value.to_string()) |> ignore
}

///|
/// Writes an empty line to standard output.
pub fn newline() -> Unit {
  write_line_mono("") |> ignore
}
