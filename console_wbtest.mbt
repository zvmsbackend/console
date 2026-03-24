///|
#cfg(not(platform="windows"))
test "consolekey from ascii letters" {
  assert_eq(ConsoleKey::from_ascii(65), A)
  assert_eq(ConsoleKey::from_ascii(90), Z)
  assert_eq(ConsoleKey::from_ascii(97 - 32), A)
}

///|
#cfg(not(platform="windows"))
test "consolekey from ascii digits and specials" {
  assert_eq(ConsoleKey::from_ascii(48), D0)
  assert_eq(ConsoleKey::from_ascii(57), D9)
  assert_eq(ConsoleKey::from_ascii(9), Tab)
  assert_eq(ConsoleKey::from_ascii(13), Enter)
  assert_eq(ConsoleKey::from_ascii(27), Escape)
}

///|
#cfg(not(platform="windows"))
test "consolekey from csi tilde number" {
  assert_eq(ConsoleKey::from_csi_tilde_number(1), Home)
  assert_eq(ConsoleKey::from_csi_tilde_number(2), Insert)
  assert_eq(ConsoleKey::from_csi_tilde_number(3), Delete)
  assert_eq(ConsoleKey::from_csi_tilde_number(4), End)
  assert_eq(ConsoleKey::from_csi_tilde_number(5), PageUp)
  assert_eq(ConsoleKey::from_csi_tilde_number(6), PageDown)
  assert_eq(ConsoleKey::from_csi_tilde_number(15), F5)
  assert_eq(ConsoleKey::from_csi_tilde_number(24), F12)
}

///|
#cfg(not(platform="windows"))
test "decode csi modifiers" {
  assert_eq(decode_csi_modifier(50), (true, false, false))
  assert_eq(decode_csi_modifier(51), (false, true, false))
  assert_eq(decode_csi_modifier(53), (false, false, true))
  assert_eq(decode_csi_modifier(56), (true, true, true))
}

///|
test "consolekeyinfo accessors" {
  let info = ConsoleKeyInfo::new('A', A, true, false, true)
  assert_eq(info.key_char, 'A')
  assert_eq(info.key, A)
  assert_eq(info.shift, true)
  assert_eq(info.alt, false)
  assert_eq(info.control, true)
}

///|
test "line buffers support unicode chars" {
  let left = ['A', '中']
  let right = ['B', '😀']
  assert_eq(line_from_buffers(left, right), "A中😀B")
}

///|
test "parse cursor report valid" {
  let bytes = [b'\x1b', b'[', b'1', b'2', b';', b'3', b'4', b'R']
  assert_eq(parse_cursor_report(bytes), Some((33, 11)))
}

///|
test "parse cursor report invalid" {
  let missing_r = [b'\x1b', b'[', b'1', b';', b'1']
  assert_eq(parse_cursor_report(missing_r), None)
}

///|
#cfg(platform="windows")
test "window position bounds" {
  assert_true(window_position_in_bounds(0, 0, 80, 25, 120, 40))
  assert_false(window_position_in_bounds(-1, 0, 80, 25, 120, 40))
  assert_false(window_position_in_bounds(50, 0, 80, 25, 120, 40))
  assert_false(window_position_in_bounds(0, 20, 80, 25, 120, 40))
}

///|
#cfg(platform="windows")
test "buffer size bounds" {
  assert_true(buffer_size_in_bounds(120, 40, 0, 0, 80, 25))
  assert_false(buffer_size_in_bounds(79, 40, 0, 0, 80, 25))
  assert_false(buffer_size_in_bounds(120, 24, 0, 0, 80, 25))
  assert_false(buffer_size_in_bounds(32767, 40, 0, 0, 80, 25))
}
