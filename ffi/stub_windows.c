// stub_windows.c - Windows-specific native stubs

#include <moonbit.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef _WIN32

#include <windows.h>
#include <io.h>
#include <signal.h>
#include <string.h>

static bool s_cancel_handlers_installed = false;
static int s_cancel_signal_write_fd = -1;
static bool s_vt_enabled = false;
static INPUT_RECORD s_cached_input_record;
static bool s_has_cached_input_record = false;
static int32_t s_last_key_char = 0;
static int32_t s_last_key_code = 0;
static int32_t s_last_key_modifiers = 0;
static bool s_has_default_colors = false;
static WORD s_default_colors = 0;

#define RIGHT_ALT_PRESSED_BIT   0x0001
#define LEFT_ALT_PRESSED_BIT    0x0002
#define RIGHT_CTRL_PRESSED_BIT  0x0004
#define LEFT_CTRL_PRESSED_BIT   0x0008
#define SHIFT_PRESSED_BIT       0x0010
#define ENHANCED_KEY_BIT        0x0100

static int win_get_buffer_info(CONSOLE_SCREEN_BUFFER_INFO *info) {
    HANDLE h_out = GetStdHandle(STD_OUTPUT_HANDLE);
    HANDLE h_err = GetStdHandle(STD_ERROR_HANDLE);
    HANDLE h_in = GetStdHandle(STD_INPUT_HANDLE);

    if (h_out != NULL && h_out != INVALID_HANDLE_VALUE && GetConsoleScreenBufferInfo(h_out, info)) {
        return 0;
    }
    if (h_err != NULL && h_err != INVALID_HANDLE_VALUE && GetConsoleScreenBufferInfo(h_err, info)) {
        return 0;
    }
    if (h_in != NULL && h_in != INVALID_HANDLE_VALUE && GetConsoleScreenBufferInfo(h_in, info)) {
        return 0;
    }
    return -1;
}

static void ensure_default_colors_cached(void) {
    if (s_has_default_colors) {
        return;
    }
    CONSOLE_SCREEN_BUFFER_INFO info;
    if (win_get_buffer_info(&info) == 0) {
        s_default_colors = info.wAttributes & 0x00FF;
        s_has_default_colors = true;
    }
}

static bool is_read_key_event(INPUT_RECORD *ir) {
    if (ir->EventType != KEY_EVENT) {
        return false;
    }

    KEY_EVENT_RECORD *key = &ir->Event.KeyEvent;
    if (!key->bKeyDown) {
        return (key->wVirtualKeyCode == VK_MENU && key->uChar.UnicodeChar != 0);
    }

    WORD vk = key->wVirtualKeyCode;
    if (vk >= VK_SHIFT && vk <= VK_MENU) {
        return false;
    }
    if (vk == VK_CAPITAL || vk == VK_NUMLOCK || vk == VK_SCROLL) {
        return false;
    }

    DWORD state = key->dwControlKeyState;
    if ((state & (LEFT_ALT_PRESSED_BIT | RIGHT_ALT_PRESSED_BIT)) != 0) {
        if (vk >= VK_NUMPAD0 && vk <= VK_NUMPAD9) {
            return false;
        }
        if ((state & ENHANCED_KEY_BIT) == 0) {
            if (vk == VK_CLEAR || vk == VK_INSERT) {
                return false;
            }
            if (vk >= VK_PRIOR && vk <= VK_DOWN) {
                return false;
            }
        }
    }

    return true;
}

static int read_console_key_event(INPUT_RECORD *out_record) {
    HANDLE h = GetStdHandle(STD_INPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) {
        return -1;
    }

    if (s_has_cached_input_record) {
        *out_record = s_cached_input_record;
        if (s_cached_input_record.Event.KeyEvent.wRepeatCount > 1) {
            s_cached_input_record.Event.KeyEvent.wRepeatCount--;
        } else {
            s_has_cached_input_record = false;
        }
        return 0;
    }

    while (1) {
        INPUT_RECORD ir;
        DWORD num_events_read = 0;
        if (!ReadConsoleInputW(h, &ir, 1, &num_events_read)) {
            return -1;
        }
        if (num_events_read == 0) {
            continue;
        }
        if (!is_read_key_event(&ir)) {
            continue;
        }
        if (ir.Event.KeyEvent.wRepeatCount > 1) {
            s_cached_input_record = ir;
            s_cached_input_record.Event.KeyEvent.wRepeatCount--;
            s_has_cached_input_record = true;
        }
        *out_record = ir;
        return 0;
    }
}

static int win_get_console_size(int *width, int *height) {
    CONSOLE_SCREEN_BUFFER_INFO info;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) {
        return -1;
    }
    if (!GetConsoleScreenBufferInfo(h, &info)) {
        return -1;
    }
    *width = (int)(info.srWindow.Right - info.srWindow.Left + 1);
    *height = (int)(info.srWindow.Bottom - info.srWindow.Top + 1);
    return 0;
}

static HANDLE win_handle_from_fd(int32_t fd) {
    if (fd == 0) {
        return GetStdHandle(STD_INPUT_HANDLE);
    }
    if (fd == 1) {
        return GetStdHandle(STD_OUTPUT_HANDLE);
    }
    if (fd == 2) {
        return GetStdHandle(STD_ERROR_HANDLE);
    }
    return NULL;
}

static bool win_is_console_handle(HANDLE h) {
    DWORD mode = 0;
    if (h == NULL || h == INVALID_HANDLE_VALUE) {
        return false;
    }
    return GetConsoleMode(h, &mode) != 0;
}

static int win_get_window_rect(SMALL_RECT *rect, COORD *buf_size) {
    CONSOLE_SCREEN_BUFFER_INFO info;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) {
        return -1;
    }
    if (!GetConsoleScreenBufferInfo(h, &info)) {
        return -1;
    }
    if (rect) {
        *rect = info.srWindow;
    }
    if (buf_size) {
        *buf_size = info.dwSize;
    }
    return 0;
}

static void ensure_vt_output_mode(void) {
    if (s_vt_enabled) {
        return;
    }
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) {
        return;
    }
    DWORD mode = 0;
    if (!GetConsoleMode(h, &mode)) {
        return;
    }
    mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if (SetConsoleMode(h, mode)) {
        s_vt_enabled = true;
    }
}

static BOOL WINAPI console_ctrl_handler(DWORD ctrl_type) {
    if (s_cancel_signal_write_fd < 0) {
        return FALSE;
    }
    uint8_t sig = 0;
    if (ctrl_type == CTRL_C_EVENT) {
        sig = 2;
    } else if (ctrl_type == CTRL_BREAK_EVENT) {
        sig = 3;
    } else {
        return FALSE;
    }
    _write(s_cancel_signal_write_fd, &sig, 1);
    return TRUE;
}

MOONBIT_FFI_EXPORT
int32_t console_init_terminal(void) { return 0; }

MOONBIT_FFI_EXPORT
void console_uninit_terminal(void) {}

MOONBIT_FFI_EXPORT
int32_t console_read_stdin(uint8_t *buffer, int32_t size) { return _read(0, buffer, size); }

MOONBIT_FFI_EXPORT
void console_init_console_before_read(uint8_t min_chars, uint8_t timeout) {
    (void)min_chars;
    (void)timeout;
}

MOONBIT_FFI_EXPORT
void console_uninit_console_after_read(void) {}

MOONBIT_FFI_EXPORT
bool console_stdin_ready(void) {
    if (s_has_cached_input_record) {
        return true;
    }

    HANDLE h = GetStdHandle(STD_INPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) {
        return false;
    }

    while (1) {
        INPUT_RECORD ir;
        DWORD num_events_read = 0;
        if (!PeekConsoleInputW(h, &ir, 1, &num_events_read)) {
            return false;
        }
        if (num_events_read == 0) {
            return false;
        }
        if (is_read_key_event(&ir)) {
            return true;
        }
        if (!ReadConsoleInputW(h, &ir, 1, &num_events_read)) {
            return false;
        }
    }
}

MOONBIT_FFI_EXPORT
int32_t console_read_key_event(void) {
    INPUT_RECORD ir;
    if (read_console_key_event(&ir) != 0) {
        return -1;
    }

    KEY_EVENT_RECORD *key = &ir.Event.KeyEvent;
    DWORD state = key->dwControlKeyState;
    int modifiers = 0;
    if (state & SHIFT_PRESSED_BIT) modifiers |= 1;
    if (state & (LEFT_ALT_PRESSED_BIT | RIGHT_ALT_PRESSED_BIT)) modifiers |= 2;
    if (state & (LEFT_CTRL_PRESSED_BIT | RIGHT_CTRL_PRESSED_BIT)) modifiers |= 4;

    s_last_key_char = (int32_t)key->uChar.UnicodeChar;
    s_last_key_code = (int32_t)key->wVirtualKeyCode;
    s_last_key_modifiers = (int32_t)modifiers;
    return 0;
}

MOONBIT_FFI_EXPORT
int32_t console_last_key_char(void) { return s_last_key_char; }

MOONBIT_FFI_EXPORT
int32_t console_last_key_code(void) { return s_last_key_code; }

MOONBIT_FFI_EXPORT
int32_t console_last_key_modifiers(void) { return s_last_key_modifiers; }

MOONBIT_FFI_EXPORT
int32_t console_get_window_size(void *ws) {
    (void)ws;
    return -1;
}

MOONBIT_FFI_EXPORT
bool console_isatty(int32_t fd) { return _isatty(fd) != 0; }

MOONBIT_FFI_EXPORT
int32_t console_poll(int32_t fd, int16_t events, int32_t timeout_ms) {
    (void)fd; (void)events; (void)timeout_ms; return -1;
}

MOONBIT_FFI_EXPORT
int32_t console_write(int32_t fd, const uint8_t *buffer, int32_t size) {
    if (size <= 0) {
        return 0;
    }

    HANDLE h = win_handle_from_fd(fd);
    if (h != NULL && h != INVALID_HANDLE_VALUE) {
        if (fd == 1 || fd == 2) {
            ensure_vt_output_mode();
        }

        if (win_is_console_handle(h)) {
            int wide_len = MultiByteToWideChar(
                CP_UTF8,
                MB_ERR_INVALID_CHARS,
                (const char *)buffer,
                size,
                NULL,
                0
            );

            if (wide_len > 0) {
                WCHAR *wide = (WCHAR *)libc_malloc((size_t)wide_len * sizeof(WCHAR));
                if (wide == NULL) {
                    return -1;
                }

                int converted = MultiByteToWideChar(
                    CP_UTF8,
                    MB_ERR_INVALID_CHARS,
                    (const char *)buffer,
                    size,
                    wide,
                    wide_len
                );
                if (converted <= 0) {
                    libc_free(wide);
                    return -1;
                }

                DWORD chars_written = 0;
                BOOL ok = WriteConsoleW(h, wide, (DWORD)wide_len, &chars_written, NULL);
                libc_free(wide);

                if (ok) {
                    return size;
                }

                DWORD err = GetLastError();
                if (err == ERROR_NO_DATA || err == ERROR_BROKEN_PIPE || err == ERROR_PIPE_NOT_CONNECTED) {
                    return size;
                }
                return -1;
            }
            // If UTF-8 conversion fails, fall back to byte write path below.
        }

        DWORD written = 0;
        BOOL ok = WriteFile(h, buffer, (DWORD)size, &written, NULL);
        if (ok) {
            return size;
        }

        DWORD err = GetLastError();
        if (err == ERROR_NO_DATA || err == ERROR_BROKEN_PIPE || err == ERROR_PIPE_NOT_CONNECTED) {
            return size;
        }
        return -1;
    }

    return _write(fd, buffer, size);
}

MOONBIT_FFI_EXPORT
int32_t console_get_control_chars(uint8_t *verase, uint8_t *veol, uint8_t *veol2, uint8_t *veof) {
    if (verase) *verase = 8;
    if (veol) *veol = '\n';
    if (veol2) *veol2 = '\n';
    if (veof) *veof = 26;
    return 0;
}

MOONBIT_FFI_EXPORT
int32_t console_get_signal_break(void) {
    HANDLE h = GetStdHandle(STD_INPUT_HANDLE);
    DWORD mode = 0;
    if (h == NULL || h == INVALID_HANDLE_VALUE || !GetConsoleMode(h, &mode)) return -1;
    return (mode & ENABLE_PROCESSED_INPUT) ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t console_set_signal_break(int32_t enable) {
    HANDLE h = GetStdHandle(STD_INPUT_HANDLE);
    DWORD mode = 0;
    if (h == NULL || h == INVALID_HANDLE_VALUE || !GetConsoleMode(h, &mode)) return -1;
    if (enable) mode |= ENABLE_PROCESSED_INPUT; else mode &= ~ENABLE_PROCESSED_INPUT;
    return SetConsoleMode(h, mode) ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int32_t console_set_cursor_position(int32_t left, int32_t top) {
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) return -1;
    COORD pos; pos.X = (SHORT)left; pos.Y = (SHORT)top;
    return SetConsoleCursorPosition(h, pos) ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int32_t console_get_cursor_left(void) {
    CONSOLE_SCREEN_BUFFER_INFO info;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE || !GetConsoleScreenBufferInfo(h, &info)) return -1;
    return (int32_t)info.dwCursorPosition.X;
}

MOONBIT_FFI_EXPORT
int32_t console_get_cursor_top(void) {
    CONSOLE_SCREEN_BUFFER_INFO info;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE || !GetConsoleScreenBufferInfo(h, &info)) return -1;
    return (int32_t)info.dwCursorPosition.Y;
}

MOONBIT_FFI_EXPORT
int32_t console_clear_screen(void) {
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) return -1;

    CONSOLE_SCREEN_BUFFER_INFO info;
    if (!GetConsoleScreenBufferInfo(h, &info)) return -1;

    DWORD cell_count = (DWORD)info.dwSize.X * (DWORD)info.dwSize.Y;
    DWORD written = 0;
    COORD home = {0, 0};

    if (!FillConsoleOutputCharacterA(h, ' ', cell_count, home, &written)) return -1;
    if (!FillConsoleOutputAttribute(h, info.wAttributes, cell_count, home, &written)) return -1;
    if (!SetConsoleCursorPosition(h, home)) return -1;
    return 0;
}

MOONBIT_FFI_EXPORT
int32_t console_set_foreground_color(int32_t color) {
    CONSOLE_SCREEN_BUFFER_INFO info;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE || !GetConsoleScreenBufferInfo(h, &info)) return -1;
    WORD attrs = info.wAttributes;
    attrs &= (WORD)~0x000F;
    attrs |= (WORD)(color & 0x000F);
    return SetConsoleTextAttribute(h, attrs) ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int32_t console_set_background_color(int32_t color) {
    CONSOLE_SCREEN_BUFFER_INFO info;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE || !GetConsoleScreenBufferInfo(h, &info)) return -1;
    WORD attrs = info.wAttributes;
    attrs &= (WORD)~0x00F0;
    attrs |= (WORD)((color & 0x000F) << 4);
    return SetConsoleTextAttribute(h, attrs) ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int32_t console_get_foreground_color(void) {
    CONSOLE_SCREEN_BUFFER_INFO info;
    if (win_get_buffer_info(&info) != 0) return -1;
    return (int32_t)(info.wAttributes & 0x000F);
}

MOONBIT_FFI_EXPORT
int32_t console_get_background_color(void) {
    CONSOLE_SCREEN_BUFFER_INFO info;
    if (win_get_buffer_info(&info) != 0) return -1;
    return (int32_t)((info.wAttributes & 0x00F0) >> 4);
}

MOONBIT_FFI_EXPORT
int32_t console_reset_colors(void) {
    ensure_default_colors_cached();
    if (!s_has_default_colors) return -1;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) return -1;
    return SetConsoleTextAttribute(h, s_default_colors) ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int32_t console_install_cancel_handlers(int32_t write_fd) {
    if (s_cancel_handlers_installed) return 0;
    s_cancel_signal_write_fd = write_fd;
    if (!SetConsoleCtrlHandler(console_ctrl_handler, TRUE)) {
        s_cancel_signal_write_fd = -1;
        return -1;
    }
    s_cancel_handlers_installed = true;
    return 0;
}

MOONBIT_FFI_EXPORT
int32_t console_restore_cancel_handlers(void) {
    if (!s_cancel_handlers_installed) return 0;
    if (!SetConsoleCtrlHandler(console_ctrl_handler, FALSE)) return -1;
    s_cancel_signal_write_fd = -1;
    s_cancel_handlers_installed = false;
    return 0;
}

MOONBIT_FFI_EXPORT
int32_t console_raise_default_signal(int32_t signum) { return raise(signum); }

MOONBIT_FFI_EXPORT
int32_t console_get_window_width(void) {
    int w = 80, h = 25;
    if (win_get_console_size(&w, &h) != 0) return 80;
    return w;
}

MOONBIT_FFI_EXPORT
int32_t console_get_window_height(void) {
    int w = 80, h = 25;
    if (win_get_console_size(&w, &h) != 0) return 25;
    return h;
}

MOONBIT_FFI_EXPORT
int32_t console_get_buffer_width(void) {
    SMALL_RECT rect;
    COORD size;
    (void)rect;
    if (win_get_window_rect(NULL, &size) != 0) return -1;
    return (int32_t)size.X;
}

MOONBIT_FFI_EXPORT
int32_t console_get_buffer_height(void) {
    COORD size;
    if (win_get_window_rect(NULL, &size) != 0) return -1;
    return (int32_t)size.Y;
}

MOONBIT_FFI_EXPORT
int32_t console_get_largest_window_width(void) {
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) return -1;
    COORD bounds = GetLargestConsoleWindowSize(h);
    return (int32_t)bounds.X;
}

MOONBIT_FFI_EXPORT
int32_t console_get_largest_window_height(void) {
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) return -1;
    COORD bounds = GetLargestConsoleWindowSize(h);
    return (int32_t)bounds.Y;
}

MOONBIT_FFI_EXPORT
int32_t console_get_window_left(void) {
    SMALL_RECT rect;
    if (win_get_window_rect(&rect, NULL) != 0) return -1;
    return (int32_t)rect.Left;
}

MOONBIT_FFI_EXPORT
int32_t console_get_window_top(void) {
    SMALL_RECT rect;
    if (win_get_window_rect(&rect, NULL) != 0) return -1;
    return (int32_t)rect.Top;
}

MOONBIT_FFI_EXPORT
int32_t console_set_window_position(int32_t left, int32_t top) {
    SMALL_RECT rect;
    COORD size;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) return -1;
    if (win_get_window_rect(&rect, &size) != 0) return -1;

    int32_t width = (int32_t)(rect.Right - rect.Left + 1);
    int32_t height = (int32_t)(rect.Bottom - rect.Top + 1);
    int32_t right = left + width - 1;
    int32_t bottom = top + height - 1;
    if (left < 0 || top < 0 || right >= size.X || bottom >= size.Y) return -1;

    SMALL_RECT dst;
    dst.Left = (SHORT)left;
    dst.Top = (SHORT)top;
    dst.Right = (SHORT)right;
    dst.Bottom = (SHORT)bottom;
    return SetConsoleWindowInfo(h, TRUE, &dst) ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int32_t console_set_buffer_size(int32_t width, int32_t height) {
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) return -1;
    COORD size;
    size.X = (SHORT)width;
    size.Y = (SHORT)height;
    return SetConsoleScreenBufferSize(h, size) ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int32_t console_set_window_size(int32_t width, int32_t height) {
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE) return -1;

    CONSOLE_SCREEN_BUFFER_INFO info;
    if (!GetConsoleScreenBufferInfo(h, &info)) return -1;

    COORD size = info.dwSize;
    if (size.X < info.srWindow.Left + width) size.X = (SHORT)(info.srWindow.Left + width);
    if (size.Y < info.srWindow.Top + height) size.Y = (SHORT)(info.srWindow.Top + height);
    if (size.X != info.dwSize.X || size.Y != info.dwSize.Y) {
      if (!SetConsoleScreenBufferSize(h, size)) return -1;
    }

    SMALL_RECT win = info.srWindow;
    win.Right = (SHORT)(win.Left + width - 1);
    win.Bottom = (SHORT)(win.Top + height - 1);
    return SetConsoleWindowInfo(h, TRUE, &win) ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int32_t console_beep_tone(int32_t frequency, int32_t duration_ms) {
    return Beep((DWORD)frequency, (DWORD)duration_ms) ? 0 : -1;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t console_get_title(void) {
    WCHAR title_w[1024];
    DWORD n = GetConsoleTitleW(title_w, 1024);
    if (n == 0) {
        return moonbit_make_bytes(0, 0);
    }

    int utf8_len = WideCharToMultiByte(CP_UTF8, 0, title_w, (int)n, NULL, 0, NULL, NULL);
    if (utf8_len <= 0) {
        return moonbit_make_bytes(0, 0);
    }

    moonbit_bytes_t bytes = moonbit_make_bytes(utf8_len, 0);
    WideCharToMultiByte(CP_UTF8, 0, title_w, (int)n, (char *)bytes, utf8_len, NULL, NULL);
    return bytes;
}

MOONBIT_FFI_EXPORT
int32_t console_set_title(const uint8_t *title) {
    if (title == NULL) {
        return -1;
    }

    int wide_len = MultiByteToWideChar(CP_UTF8, 0, (const char *)title, -1, NULL, 0);
    if (wide_len <= 0) {
        return -1;
    }

    WCHAR *title_w = (WCHAR *)libc_malloc((size_t)wide_len * sizeof(WCHAR));
    if (title_w == NULL) {
        return -1;
    }

    MultiByteToWideChar(CP_UTF8, 0, (const char *)title, -1, title_w, wide_len);
    BOOL ok = SetConsoleTitleW(title_w);
    libc_free(title_w);
    return ok ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int32_t console_get_cursor_size(void) {
    CONSOLE_CURSOR_INFO info;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h == NULL || h == INVALID_HANDLE_VALUE || !GetConsoleCursorInfo(h, &info)) {
        return -1;
    }
    return (int32_t)info.dwSize;
}

MOONBIT_FFI_EXPORT
int32_t console_set_cursor_size(int32_t size) {
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    CONSOLE_CURSOR_INFO info;
    if (h == NULL || h == INVALID_HANDLE_VALUE || !GetConsoleCursorInfo(h, &info)) {
        return -1;
    }
    info.dwSize = (DWORD)size;
    return SetConsoleCursorInfo(h, &info) ? 0 : -1;
}

#endif
