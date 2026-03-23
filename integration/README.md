# Integration Tests

## Linux

Run the default Linux integration suite:

```bash
python3 integration/run_linux_integration.py
```

This covers:

- redirected stdin/stdout flags
- redirected `ReadLine` CRLF behavior
- redirected `Read` UTF-8 code point behavior
- TTY `ReadKey` behavior
- TTY window size availability

Signal-related cases are available but disabled by default:

```bash
python3 integration/run_linux_integration.py --include-signal
```

Use the signal cases for exploratory validation while the async signal
dispatch/read loop interaction is being refined.
