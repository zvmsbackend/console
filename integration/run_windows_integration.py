import os
import signal
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BIN_PATH = REPO_ROOT / "_build" / "native" / "debug" / "build" / "integration" / "test_console" / "test_console.exe"
BIN_PATH_ASYNC = REPO_ROOT / "_build" / "native" / "debug" / "build" / "integration" / "test_console_async" / "test_console_async.exe"

PASS = "PASS"
FAIL = "FAIL"
SKIP = "SKIP"

def ensure_binary():
    print("Building binaries...")
    subprocess.check_call(["moon", "build", "integration/test_console"], cwd=REPO_ROOT)
    subprocess.check_call(["moon", "build", "integration/test_console_async"], cwd=REPO_ROOT)

def run_pipe_case(scenario, stdin_data=b"", timeout=5.0, bin_path=BIN_PATH):
    proc = subprocess.Popen(
        [str(bin_path), scenario],
        cwd=str(REPO_ROOT),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        out, err = proc.communicate(stdin_data, timeout=timeout)
        return proc.returncode, out.decode("utf-8", errors="replace"), err.decode("utf-8", errors="replace")
    except subprocess.TimeoutExpired:
        proc.kill()
        return -1, "", "Timeout"

def run_windows_signal_case(scenario, event_name="CTRL_BREAK_EVENT", bin_path=BIN_PATH):
    """
    Windows signals (Ctrl+C) require the process to be in a new process group.
    """
    # Use CREATE_NEW_PROCESS_GROUP to allow sending console control events
    # Note: subprocess.CREATE_NEW_PROCESS_GROUP = 0x00000200
    CREATE_NEW_PROCESS_GROUP = 0x00000200
    
    proc = subprocess.Popen(
        [str(bin_path), scenario],
        cwd=str(REPO_ROOT),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        creationflags=CREATE_NEW_PROCESS_GROUP
    )
    
    time.sleep(1.2) # Wait for process to initialize handlers and print READY

    event_value = getattr(signal, event_name, None)
    if event_value is None:
        proc.kill()
        out, err = proc.communicate()
        return -1, out.decode("utf-8", errors="replace"), f"{event_name} not available: {err.decode('utf-8', errors='replace')}"

    os.kill(proc.pid, event_value)
    
    try:
        # Give it some time to process the signal and print the marker
        out, err = proc.communicate(timeout=3.0)
        return proc.returncode, out.decode("utf-8", errors="replace"), err.decode("utf-8", errors="replace")
    except subprocess.TimeoutExpired:
        proc.kill()
        out, err = proc.communicate()
        return -1, out.decode("utf-8", errors="replace"), err.decode("utf-8", errors="replace")

def parse_window_size(output: str):
    marker = "W="
    if marker not in output or "H=" not in output:
        return None
    # expected shape: "W=<int> H=<int>"
    try:
        after_w = output.split("W=", 1)[1]
        w_str, rest = after_w.split(" ", 1)
        h_str = rest.split("H=", 1)[1].split()[0]
        return int(w_str), int(h_str)
    except Exception:
        return None


def run_case(name, fn, required=True):
    try:
        status, detail = fn()
    except Exception as ex:
        status, detail = FAIL, str(ex)

    print(f"{status}: {name}" + (f" ({detail})" if detail else ""))

    if status == FAIL and required:
        return False, status
    return True, status

def main():
    try:
        ensure_binary()
    except Exception as e:
        print(f"Failed to build: {e}")
        return 1

    required_total = 0
    required_passed = 0
    optional_total = 0
    optional_passed = 0
    optional_skipped = 0

    print("\nRunning Windows Integration Tests...")

    def case_redirect_flags():
        rc, out, err = run_pipe_case("redirect-flags")
        if rc != 0:
            return FAIL, f"rc={rc}, err={err}"
        if "IN=true" not in out or "OUT=true" not in out:
            return FAIL, f"unexpected output: {out}"
        return PASS, ""

    def case_redirected_read_line_two():
        rc, out, err = run_pipe_case("redirected-read-line-two", b"hello\r\nworld\n")
        if rc != 0:
            return FAIL, f"rc={rc}, err={err}"
        if "L1=hello" not in out or "L2=world" not in out:
            return FAIL, f"unexpected output: {out}"
        return PASS, ""

    def case_redirected_read_char_two():
        rc, out, err = run_pipe_case("redirected-read-char-two", "éx".encode("utf-8"))
        if rc != 0:
            return FAIL, f"rc={rc}, err={err}"
        if "C1=233" not in out or "C2=120" not in out:
            return FAIL, f"unexpected output: {out}"
        return PASS, ""

    def case_window_size_positive():
        rc, out, err = run_pipe_case("window-size")
        if rc != 0:
            return FAIL, f"rc={rc}, err={err}"
        size = parse_window_size(out)
        if size is None:
            return FAIL, f"missing window size in output: {out}"
        w, h = size
        if w <= 0 or h <= 0:
            return FAIL, f"invalid window size W={w} H={h}"
        return PASS, ""

    def case_signal_handled_sync_break_required():
        rc, out, err = run_windows_signal_case("cancel-handled-wait-signal", event_name="CTRL_BREAK_EVENT")
        if rc != 0:
            return FAIL, f"rc={rc}, out={out}, err={err}"
        if "HANDLED=ControlBreak" in out and "AFTER_SIGNAL" in out:
            return PASS, ""
        return FAIL, f"unexpected output: {out}, err={err}"

    def case_signal_handled_async_break_required():
        rc, out, err = run_windows_signal_case(
            "async-cancel-handled-wait-signal",
            event_name="CTRL_BREAK_EVENT",
            bin_path=BIN_PATH_ASYNC,
        )
        if rc != 0:
            return FAIL, f"rc={rc}, out={out}, err={err}"
        if "HANDLED=ControlBreak" in out and "AFTER_SIGNAL" in out:
            return PASS, ""
        return FAIL, f"unexpected output: {out}, err={err}"

    def case_signal_handled_sync_ctrl_c_optional():
        rc, out, err = run_windows_signal_case("cancel-handled-wait-signal", event_name="CTRL_C_EVENT")
        if rc == 0 and "HANDLED=ControlC" in out and "AFTER_SIGNAL" in out:
            return PASS, ""
        return SKIP, f"ctrl-c not observed (rc={rc}, out={out}, err={err})"

    def case_signal_handled_async_ctrl_c_optional():
        rc, out, err = run_windows_signal_case(
            "async-cancel-handled-wait-signal",
            event_name="CTRL_C_EVENT",
            bin_path=BIN_PATH_ASYNC,
        )
        if rc == 0 and "HANDLED=ControlC" in out and "AFTER_SIGNAL" in out:
            return PASS, ""
        return SKIP, f"async ctrl-c not observed (rc={rc}, out={out}, err={err})"

    required_cases = [
        ("redirect-flags", case_redirect_flags),
        ("redirected-read-line-two", case_redirected_read_line_two),
        ("redirected-read-char-two", case_redirected_read_char_two),
        ("window-size-positive", case_window_size_positive),
        ("signal-handled-sync-break", case_signal_handled_sync_break_required),
        ("signal-handled-async-break", case_signal_handled_async_break_required),
    ]

    optional_cases = [
        ("signal-handled-sync-ctrl-c", case_signal_handled_sync_ctrl_c_optional),
        ("signal-handled-async-ctrl-c", case_signal_handled_async_ctrl_c_optional),
    ]

    print("\nRequired cases:")
    for name, fn in required_cases:
        required_total += 1
        ok, status = run_case(name, fn, required=True)
        if ok and status == PASS:
            required_passed += 1
        elif not ok:
            print("\nStopping due to required case failure.")
            print(f"Summary: required {required_passed}/{required_total} passed")
            return 1

    print("\nOptional cases (best effort):")
    for name, fn in optional_cases:
        optional_total += 1
        _, status = run_case(name, fn, required=False)
        if status == PASS:
            optional_passed += 1
        elif status == SKIP:
            optional_skipped += 1

    print("\nSummary:")
    print(f"- Required: {required_passed}/{required_total} passed")
    print(f"- Optional: {optional_passed}/{optional_total} passed, {optional_skipped} skipped")
    return 0

if __name__ == "__main__":
    sys.exit(main())
