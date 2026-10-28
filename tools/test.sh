#!/usr/bin/env bash
# Runs the test suites headless (no editor, no stale caches).
#   tools/test.sh                 all suites, then the stairs walk check (tools/walk_check.tscn)
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
# Stairs need real physics frames, which suites can't step: a full run walks them too.
if [ -z "${1:-}" ]; then
	walk="$("$GODOT" --headless --path . res://tools/walk_check.tscn 2>&1)"
	wcode=$?
	echo "$walk" | grep -E '^(FAIL|RESULT)|walk_check:|SCRIPT ERROR|Parse Error' | sed 's/^RESULT/WALK RESULT/'
	[ $wcode -ne 0 ] && code=1
fi
exit $code
