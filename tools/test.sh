#!/usr/bin/env bash
# Runs the test suites headless (no editor, no stale caches).
#   tools/test.sh                 all suites
#   tools/test.sh nature          one suite
#   tools/test.sh nature venom    tests of that suite whose name contains "venom"
# Godot: $GODOT_BIN, else the console build on this machine.
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT_BIN:-C:/Users/Djole/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe}"
args=()
[ -n "${1:-}" ] && args+=("--suite=$1")
[ -n "${2:-}" ] && args+=("--test=$2")
"$GODOT" --headless --path . --import >/dev/null 2>&1
out="$("$GODOT" --headless --path . res://tests/run_all.tscn -- "${args[@]}" 2>&1)"
code=$?
echo "$out" | grep -E '^(FAIL|LOAD ERROR|RESULT)|passed, .* failed|SCRIPT ERROR|Parse Error' | grep -v 'addons/'
exit $code
