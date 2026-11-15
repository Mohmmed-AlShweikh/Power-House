# Reproducible visual tests

Run `tool/test_visual.sh` on Linux with a C compiler and the configured Flutter SDK. Override `PORTAL_FLUTTER_BIN` for another SDK installation. To run all tests, use `PORTAL_TEST_TARGET=test tool/test_visual.sh`.

The production greeting uses `DateTime.now()`. These golden references were captured on 2026-11-15 at 09:00 UTC. The runner compiles a small test-only `gettimeofday` interposer into ignored `.dart_tool/` and pins only the test process wall clock to that instant. Monotonic clocks, animation timers, providers and application sources remain unchanged. The library is never linked into the APK and is only loaded by this runner. No golden tolerance or masked regions are used.

State captures wait for tab transitions and assert the actual requested destination or dialog is visible before comparison. Signed phone and amount isolates are also checked.
