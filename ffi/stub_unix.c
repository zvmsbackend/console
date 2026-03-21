// stub_unix.c - Unix-specific C stubs

#include <moonbit.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/poll.h>
#include <errno.h>
#include <signal.h>

typedef struct {
    uint16_t row;
    uint16_t col;
    uint16_t x_pixel;
    uint16_t y_pixel;
} console_win_size;

static struct termios s_orig_termios;
static bool s_terminal_initialized = false;
static volatile sig_atomic_t s_pending_signal = 0;
static bool s_cancel_handlers_installed = false;
static struct sigaction s_prev_sigint;
static struct sigaction s_prev_sigquit;

static void console_cancel_signal_handler(int signum) {
    if (s_pending_signal == 0) {
        s_pending_signal = signum;
    }
}

MOONBIT_FFI_EXPORT
int32_t console_init_terminal(void) {
    if (!isatty(STDIN_FILENO)) {
        return -1;
    }
    if (tcgetattr(STDIN_FILENO, &s_orig_termios) == -1) {
        return -1;
    }

    struct termios raw = s_orig_termios;
    raw.c_lflag &= ~(ICANON | ECHO | ISIG | IEXTEN);
    raw.c_iflag &= ~(BRKINT | ICRNL | IGNBRK | IGNCR | INLCR | INPCK | ISTRIP | IXON | IXOFF);
    raw.c_oflag &= ~(OPOST);
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;

    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1) {
        return -1;
    }

    s_terminal_initialized = true;
    return 0;
}

MOONBIT_FFI_EXPORT
void console_uninit_terminal(void) {
    if (s_terminal_initialized) {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &s_orig_termios);
        s_terminal_initialized = false;
    }
}

MOONBIT_FFI_EXPORT
int32_t console_read_stdin(uint8_t *buffer, int32_t size) {
    ssize_t n = read(STDIN_FILENO, buffer, (size_t)size);
    if (n == -1 && errno == EINTR) {
        return 0;
    }
    return (int32_t)n;
}

MOONBIT_FFI_EXPORT
void console_init_console_before_read(uint8_t min_chars, uint8_t timeout) {
    struct termios raw;
    if (tcgetattr(STDIN_FILENO, &raw) == 0) {
        raw.c_cc[VMIN] = min_chars;
        raw.c_cc[VTIME] = timeout;
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
    }
}

MOONBIT_FFI_EXPORT
void console_uninit_console_after_read(void) {
    if (s_terminal_initialized) {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &s_orig_termios);
    }
}

MOONBIT_FFI_EXPORT
bool console_stdin_ready(void) {
    int bytes_available;
    if (ioctl(STDIN_FILENO, FIONREAD, &bytes_available) == -1) {
        return false;
    }
    return bytes_available > 0;
}

MOONBIT_FFI_EXPORT
int32_t console_get_window_size(console_win_size *ws) {
    struct winsize w;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == -1) {
        return -1;
    }
    ws->row = w.ws_row;
    ws->col = w.ws_col;
    ws->x_pixel = w.ws_xpixel;
    ws->y_pixel = w.ws_ypixel;
    return 0;
}

MOONBIT_FFI_EXPORT
bool console_isatty(int32_t fd) {
    return isatty(fd) == 1;
}

MOONBIT_FFI_EXPORT
int32_t console_poll(int32_t fd, int16_t events, int32_t timeout_ms) {
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = events;
    pfd.revents = 0;

    int ret = poll(&pfd, 1, timeout_ms);
    if (ret > 0) {
        return (int32_t)pfd.revents;
    }
    return ret;
}

MOONBIT_FFI_EXPORT
int32_t console_write(int32_t fd, const uint8_t *buffer, int32_t size) {
    return (int32_t)write(fd, buffer, (size_t)size);
}

MOONBIT_FFI_EXPORT
int32_t console_get_control_chars(uint8_t *verase, uint8_t *veol, uint8_t *veol2, uint8_t *veof) {
    struct termios raw;
    if (tcgetattr(STDIN_FILENO, &raw) == -1) {
        return -1;
    }
    if (verase) *verase = raw.c_cc[VERASE];
    if (veol) *veol = raw.c_cc[VEOL];
    if (veol2) *veol2 = raw.c_cc[VEOL2];
    if (veof) *veof = raw.c_cc[VEOF];
    return 0;
}

MOONBIT_FFI_EXPORT
int32_t console_get_signal_break(void) {
    struct termios raw;
    if (tcgetattr(STDIN_FILENO, &raw) == -1) {
        return -1;
    }
    return (raw.c_lflag & ISIG) ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t console_set_signal_break(int32_t enable) {
    struct termios raw;
    if (tcgetattr(STDIN_FILENO, &raw) == -1) {
        return -1;
    }
    if (enable) {
        raw.c_lflag |= ISIG;
    } else {
        raw.c_lflag &= ~ISIG;
    }
    return tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

MOONBIT_FFI_EXPORT
int32_t console_install_cancel_handlers(void) {
    if (s_cancel_handlers_installed) {
        return 0;
    }

    struct sigaction sa;
    sa.sa_handler = console_cancel_signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;

    if (sigaction(SIGINT, &sa, &s_prev_sigint) != 0) {
        return -1;
    }
    if (sigaction(SIGQUIT, &sa, &s_prev_sigquit) != 0) {
        sigaction(SIGINT, &s_prev_sigint, NULL);
        return -1;
    }

    s_pending_signal = 0;
    s_cancel_handlers_installed = true;
    return 0;
}

MOONBIT_FFI_EXPORT
int32_t console_restore_cancel_handlers(void) {
    if (!s_cancel_handlers_installed) {
        return 0;
    }

    int ok_int = sigaction(SIGINT, &s_prev_sigint, NULL);
    int ok_quit = sigaction(SIGQUIT, &s_prev_sigquit, NULL);
    if (ok_int != 0 || ok_quit != 0) {
        return -1;
    }

    s_pending_signal = 0;
    s_cancel_handlers_installed = false;
    return 0;
}

MOONBIT_FFI_EXPORT
int32_t console_take_pending_signal(void) {
    int32_t signum = (int32_t)s_pending_signal;
    s_pending_signal = 0;
    return signum;
}

MOONBIT_FFI_EXPORT
int32_t console_get_window_width(void) {
    struct winsize w;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == -1) {
        return 80;
    }
    return (int32_t)w.ws_col;
}

MOONBIT_FFI_EXPORT
int32_t console_get_window_height(void) {
    struct winsize w;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == -1) {
        return 25;
    }
    return (int32_t)w.ws_row;
}
