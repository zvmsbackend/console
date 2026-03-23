#!/usr/bin/env python3

import os
import pty
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
BIN_PATH = REPO_ROOT / "_build" / "native" / "debug" / "build" / "integration" / "test_console" / "test_console.exe"
BUILD_CMD = ["moon", "-C", REPO_ROOT, "build", "integration/test_console"]
BIN_PATH_ASYNC = REPO_ROOT / "_build" / "native" / "debug" / "build" / "integration" / "test_console_async" / "test_console_async.exe"
BUILD_CMD_ASYNC = ["moon", "-C", REPO_ROOT, "build", "integration/test_console_async"]


def ensure_binary():
    subprocess.check_call(BUILD_CMD, cwd=REPO_ROOT)
    subprocess.check_call(BUILD_CMD_ASYNC, cwd=REPO_ROOT)


def run_pipe_case(scenario: str, stdin_data: bytes = b"", timeout: float = 5.0, bin_path: Path = BIN_PATH):
    proc = subprocess.Popen(
        [bin_path, scenario],
        cwd=REPO_ROOT,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    out, err = proc.communicate(stdin_data, timeout=timeout)
    return proc.returncode, out.decode("utf-8", errors="replace"), err.decode("utf-8", errors="replace")


def run_pty_case(
    scenario: str,
    input_bytes: bytes = b"",
    timeout: float = 20.0,
    input_delay: float = 0.5,
    actions=None,
    bin_path: Path = BIN_PATH,
):
    master_fd, slave_fd = pty.openpty()
    # 24 rows, 80 columns
    winsz = struct.pack("HHHH", 24, 80, 0, 0)
    try:
        import fcntl
        fcntl.ioctl(master_fd, termios.TIOCSWINSZ, winsz)
    except Exception:
        pass
    proc = subprocess.Popen(
        [bin_path, scenario],
        cwd=REPO_ROOT,
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        close_fds=True,
    )
    os.close(slave_fd)

    scheduled = []
    if actions is not None:
        scheduled.extend(actions)
    elif input_bytes:
        scheduled.append((input_delay, "write", input_bytes))
    scheduled.sort(key=lambda x: x[0])
    action_idx = 0

    output = bytearray()
    start = time.time()
    while True:
        if time.time() - start > timeout:
            proc.kill()
            os.close(master_fd)
            raise TimeoutError(f"PTY case timed out: {scenario}")

        elapsed = time.time() - start
        while action_idx < len(scheduled) and scheduled[action_idx][0] <= elapsed:
            _, kind, payload = scheduled[action_idx]
            if kind == "write":
                os.write(master_fd, payload)
            elif kind == "signal":
                os.kill(proc.pid, payload)
            action_idx += 1

        r, _, _ = select.select([master_fd], [], [], 0.1)
        if r:
            try:
                chunk = os.read(master_fd, 4096)
            except OSError:
                chunk = b""
            if chunk:
                output.extend(chunk)

        rc = proc.poll()
        if rc is not None:
            # drain remaining bytes once process exits
            while True:
                r2, _, _ = select.select([master_fd], [], [], 0.05)
                if not r2:
                    break
                try:
                    chunk = os.read(master_fd, 4096)
                except OSError:
                    chunk = b""
                if not chunk:
                    break
                output.extend(chunk)
            os.close(master_fd)
            return rc, output.decode("utf-8", errors="replace")


def assert_true(cond: bool, message: str):
    if not cond:
        raise AssertionError(message)


def case_redirect_flags_pipe():
    rc, out, err = run_pipe_case("redirect-flags")
    assert_true(rc == 0, f"redirect-flags exited {rc}: {err}")
    assert_true("IN=true" in out, f"expected IN=true, got: {out}")
    assert_true("OUT=true" in out, f"expected OUT=true, got: {out}")
    assert_true("ERR=true" in out, f"expected ERR=true, got: {out}")


def case_redirected_read_line_crlf():
    rc, out, err = run_pipe_case("redirected-read-line-two", b"hello\r\nworld\n")
    assert_true(rc == 0, f"redirected-read-line-two exited {rc}: {err}")
    assert_true("L1=hello" in out, f"expected L1=hello, got: {out}")
    assert_true("L2=world" in out, f"expected L2=world, got: {out}")


def case_redirected_read_char_utf8():
    rc, out, err = run_pipe_case("redirected-read-char-two", "éx".encode("utf-8"))
    assert_true(rc == 0, f"redirected-read-char-two exited {rc}: {err}")
    assert_true("C1=233" in out, f"expected C1=233, got: {out}")
    assert_true("C2=120" in out, f"expected C2=120, got: {out}")


def case_tty_read_key_upper_a():
    rc, out = run_pty_case("read-key", b"A", timeout=20.0, input_delay=1.0)
    assert_true(rc == 0, f"read-key exited {rc}: {out}")
    assert_true("KC=65" in out, f"expected KC=65, got: {out}")
    assert_true("K=65" in out, f"expected K=65, got: {out}")
    assert_true("S=true" in out, f"expected S=true, got: {out}")


def case_tty_window_size_positive():
    rc, out = run_pty_case("window-size")
    assert_true(rc == 0, f"window-size exited {rc}: {out}")
    m = re.search(r"W=(\d+) H=(\d+)", out)
    assert_true(m is not None, f"missing window size output: {out}")
    if m is None:
        raise AssertionError(f"missing window size output: {out}")
    w = int(m.group(1))
    h = int(m.group(2))
    assert_true(w > 0 and h > 0, f"invalid window size W={w} H={h}")


def case_tty_cancel_handled_then_read_key():
    rc, out = run_pty_case(
        "cancel-handled-read-key",
        timeout=20.0,
        actions=[
            (1.0, "signal", signal.SIGINT),
            (2.0, "write", b"x"),
        ],
    )
    assert_true(rc == 0, f"cancel-handled-read-key exited {rc}: {out}")
    assert_true("HANDLED=ControlC" in out, f"expected HANDLED marker, got: {out}")
    assert_true("AFTER KC=120" in out, f"expected AFTER KC=120, got: {out}")


def case_tty_cancel_unhandled_terminates():
    rc, out = run_pty_case(
        "cancel-unhandled-read-key",
        timeout=20.0,
        actions=[
            (1.0, "signal", signal.SIGINT),
            (2.0, "write", b"z"),
        ],
    )
    # Process should terminate due to default signal behavior.
    assert_true(rc != 0, f"expected non-zero exit on unhandled cancel, got {rc}: {out}")
    assert_true("UNHANDLED=ControlC" in out, f"expected UNHANDLED marker, got: {out}")
    assert_true("SHOULD_NOT_REACH" not in out, f"unexpected post-signal output: {out}")


def case_tty_async_cancel_handled_then_read_key():
    rc, out = run_pty_case(
        "async-cancel-handled-read-key",
        timeout=20.0,
        actions=[
            (1.0, "signal", signal.SIGINT),
            (2.0, "write", b"x"),
        ],
        bin_path=BIN_PATH_ASYNC,
    )
    assert_true(rc == 0, f"async-cancel-handled-read-key exited {rc}: {out}")
    assert_true("HANDLED=ControlC" in out, f"expected HANDLED marker, got: {out}")
    assert_true("AFTER KC=120" in out, f"expected AFTER KC=120, got: {out}")


def case_tty_async_cancel_unhandled_terminates():
    rc, out = run_pty_case(
        "async-cancel-unhandled-read-key",
        timeout=20.0,
        actions=[
            (1.0, "signal", signal.SIGINT),
            (2.0, "write", b"z"),
        ],
        bin_path=BIN_PATH_ASYNC,
    )
    # Process should terminate due to default signal behavior.
    assert_true(rc != 0, f"expected non-zero exit on unhandled async cancel, got {rc}: {out}")
    assert_true("UNHANDLED=ControlC" in out, f"expected UNHANDLED marker, got: {out}")
    assert_true("SHOULD_NOT_REACH" not in out, f"unexpected post-signal output: {out}")


def main():
    ensure_binary()
    cases = [
        ("redirect_flags_pipe", case_redirect_flags_pipe),
        ("redirected_read_line_crlf", case_redirected_read_line_crlf),
        ("redirected_read_char_utf8", case_redirected_read_char_utf8),
        ("tty_read_key_upper_a", case_tty_read_key_upper_a),
        ("tty_window_size_positive", case_tty_window_size_positive),
        ("tty_cancel_handled_then_read_key", case_tty_cancel_handled_then_read_key),
        ("tty_cancel_unhandled_terminates", case_tty_cancel_unhandled_terminates),
        ("tty_async_cancel_handled_then_read_key", case_tty_async_cancel_handled_then_read_key),
        ("tty_async_cancel_unhandled_terminates", case_tty_async_cancel_unhandled_terminates),
    ]

    failed = []
    for name, fn in cases:
        try:
            fn()
            print(f"PASS {name}")
        except Exception as ex:
            failed.append((name, str(ex)))
            print(f"FAIL {name}: {ex}")

    if failed:
        print("\nIntegration failures:")
        for name, msg in failed:
            print(f"- {name}: {msg}")
        return 1

    print("\nAll linux integration cases passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
