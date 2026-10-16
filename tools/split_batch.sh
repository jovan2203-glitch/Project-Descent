#!/usr/bin/env bash
# Moves a run of consecutive player.gd sections into one component.
#   tools/split_batch.sh "<first banner text>" "<last banner text>" file.gd ClassName var
# (banner text = what follows "# --- " at the start of the section's banner line)
# SPLIT_HOST=menu tools/split_batch.sh ... does the same for scripts/main_menu.gd -> scripts/menu/.
set -eu
cd "$(dirname "$0")/.."
first="$1"; last="$2"; file="$3"; cls="$4"; var="$5"
case "${SPLIT_HOST:-player}" in
	player) f=scripts/player.gd; dir=scripts/player ;;
	menu) f=scripts/main_menu.gd; dir=scripts/menu ;;
	*) echo "SPLIT_HOST must be player or menu" >&2; exit 1 ;;
esac
s=$(grep -n "^# --- $first" $f | head -1 | cut -d: -f1)
l=$(grep -n "^# --- $last" $f | head -1 | cut -d: -f1)
[ -n "$s" ] && [ -n "$l" ] || { echo "banner not found" >&2; exit 1; }
e=$(awk -v s="$l" 'NR>s && /^# --- /{print NR-1; exit}' $f)
[ -z "$e" ] && e=$(wc -l < $f)
if grep -qE "^(static func|func|var|const|@[a-z]+ var) $var\b" $f; then echo "$f already has a member named $var" >&2; exit 1; fi
# ... nor a local variable or parameter (it would hide the component in that function).
if grep -qsE "(\bvar|\bfor|[(,]) +$var\b" $f $dir/*.gd; then echo "$var is already a local name in $f or a component" >&2; exit 1; fi
perl tools/split_section.pl "$s" "$e" "$file" "$cls" "$var"
