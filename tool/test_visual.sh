#!/usr/bin/env bash
# Pin the test process's wall clock. Production code/providers are untouched.
set -euo pipefail
PORTAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PORTAL_ROOT"
mkdir -p .dart_tool
cc -shared -fPIC -O2 tool/visual_clock.c -ldl -o .dart_tool/portal_visual_clock.so
PORTAL_CLOCK_LIB="$PORTAL_ROOT/.dart_tool/portal_visual_clock.so"
PORTAL_FLUTTER_BIN="${PORTAL_FLUTTER_BIN:-/workspace/toolchains/flutter/bin/flutter}"
export PUB_CACHE="${PUB_CACHE:-/workspace/toolchains/pub-cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/toolchains/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/toolchains/cache}"
export ANALYZER_STATE_LOCATION_OVERRIDE="${ANALYZER_STATE_LOCATION_OVERRIDE:-/workspace/toolchains/analyzer-state}"
export DART_SUPPRESS_ANALYTICS=true
export TZ=Etc/UTC
export PORTAL_VISUAL_CLOCK_EPOCH=1794733200
export LD_PRELOAD="$PORTAL_CLOCK_LIB${LD_PRELOAD:+:$LD_PRELOAD}"
exec "$PORTAL_FLUTTER_BIN" test --no-pub "${PORTAL_TEST_TARGET:-test/redesign}" "$@"
