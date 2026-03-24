// types.mbt - Console type definitions

///|
/// Represents supported console colors.
pub enum ConsoleColor {
  Black = 0
  DarkBlue = 1
  DarkGreen = 2
  DarkCyan = 3
  DarkRed = 4
  DarkMagenta = 5
  DarkYellow = 6
  Gray = 7
  DarkGray = 8
  Blue = 9
  Green = 10
  Cyan = 11
  Red = 12
  Magenta = 13
  Yellow = 14
  White = 15
} derive(Show, Eq)

///|
/// Converts a console color to its platform numeric value.
pub fn ConsoleColor::to_int(self : ConsoleColor) -> Int = "%identity"

///|
/// Represents logical key values returned by `read_key`.
pub(all) enum ConsoleKey {
  Backspace = 8
  Tab = 9
  Enter = 13
  Escape = 27
  Space = 32
  PageUp = 33
  PageDown = 34
  End = 35
  Home = 36
  LeftArrow = 37
  UpArrow = 38
  RightArrow = 39
  DownArrow = 40
  Insert = 45
  Delete = 46
  D0 = 48
  D1 = 49
  D2 = 50
  D3 = 51
  D4 = 52
  D5 = 53
  D6 = 54
  D7 = 55
  D8 = 56
  D9 = 57
  A = 65
  B = 66
  C = 67
  D = 68
  E = 69
  F = 70
  G = 71
  H = 72
  I = 73
  J = 74
  K = 75
  L = 76
  M = 77
  N = 78
  O = 79
  P = 80
  Q = 81
  R = 82
  S = 83
  T = 84
  U = 85
  V = 86
  W = 87
  X = 88
  Y = 89
  Z = 90
  LeftWindows = 91
  RightWindows = 92
  Apps = 93
  Sleep = 95
  NumPad0 = 96
  NumPad1 = 97
  NumPad2 = 98
  NumPad3 = 99
  NumPad4 = 100
  NumPad5 = 101
  NumPad6 = 102
  NumPad7 = 103
  NumPad8 = 104
  NumPad9 = 105
  Multiply = 106
  Add = 107
  Separator = 108
  Subtract = 109
  Decimal = 110
  Divide = 111
  F1 = 112
  F2 = 113
  F3 = 114
  F4 = 115
  F5 = 116
  F6 = 117
  F7 = 118
  F8 = 119
  F9 = 120
  F10 = 121
  F11 = 122
  F12 = 123
  F13 = 124
  F14 = 125
  F15 = 126
  F16 = 127
  F17 = 128
  F18 = 129
  F19 = 130
  F20 = 131
  F21 = 132
  F22 = 133
  F23 = 134
  F24 = 135
} derive(Show, Eq)

///|
/// Converts a console key to its numeric value.
pub fn ConsoleKey::to_int(self : ConsoleKey) -> Int = "%identity"

///|
/// Describes one keyboard event with key value and modifier flags.
pub struct ConsoleKeyInfo {
  key_char : Char
  key : ConsoleKey
  shift : Bool
  alt : Bool
  control : Bool
}

///|
/// Creates a `ConsoleKeyInfo` value.
pub fn ConsoleKeyInfo::new(
  key_char : Char,
  key : ConsoleKey,
  shift : Bool,
  alt : Bool,
  control : Bool,
) -> ConsoleKeyInfo {
  { key_char, key, shift, alt, control }
}

///|
/// Represents cancel-signal kinds used by cancel key handlers.
pub(all) enum ConsoleSpecialKey {
  ControlC = 0
  ControlBreak = 1
}

///|
/// Represents standard process handles (stdin/stdout/stderr).
pub(all) enum StandardHandle {
  StandardInput = 0
  StandardOutput = 1
  StandardError = 2
}
