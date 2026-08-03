#!/bin/sh
# Claude Code status line. Reads the session JSON on stdin, prints one line.
# Shows: dir (+ worktree), branch, context usage, 5h session usage.
set -eu

# gruvbox-material, matching the tmux status bar
C_DIM='\033[38;2;146;131;116m'
C_FG='\033[38;2;221;199;161m'
C_YELLOW='\033[38;2;216;166;87m'
C_AQUA='\033[38;2;125;174;163m'
C_GREEN='\033[38;2;169;182;101m'
C_RED='\033[38;2;234;105;98m'
C_PURPLE='\033[38;2;211;134;155m'
C_CLAUDE='\033[38;2;217;119;87m'
C_FLAMINGO='\033[38;2;242;205;205m'
C_OFF='\033[0m'

SEP="${C_DIM} | ${C_OFF}"
CELLS=8

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
	printf '%s\n' "${PWD}"
	exit 0
fi

# -1 stands in for "not reported yet", which happens on the first render.
fields=$(printf '%s' "$input" | jq -r '[
	(.workspace.current_dir // .cwd // ""),
	(.context_window.used_percentage // -1 | floor),
	(.rate_limits.five_hour.used_percentage // -1 | floor),
	(.rate_limits.five_hour.resets_at // -1 | floor),
	(.rate_limits.seven_day.used_percentage // -1 | floor),
	(.rate_limits.seven_day.resets_at // -1 | floor)
] | @tsv')

dir=$(printf '%s' "$fields" | cut -f1)
ctx=$(printf '%s' "$fields" | cut -f2)
session=$(printf '%s' "$fields" | cut -f3)
resets_at=$(printf '%s' "$fields" | cut -f4)
week=$(printf '%s' "$fields" | cut -f5)
week_resets=$(printf '%s' "$fields" | cut -f6)

# Colour by how close to full something is.
heat() {
	if [ "$1" -ge 80 ]; then
		printf '%b' "$C_RED"
	elif [ "$1" -ge 50 ]; then
		printf '%b' "$C_YELLOW"
	else
		printf '%b' "$C_GREEN"
	fi
}

# One glyph per 100/CELLS percent, rounded.
BAR_FULL='▬'
BAR_EMPTY='▭'

bar() {
	filled=$((($1 * CELLS + 50) / 100))
	[ "$filled" -gt "$CELLS" ] && filled=$CELLS
	i=0
	while [ "$i" -lt "$CELLS" ]; do
		if [ "$i" -lt "$filled" ]; then printf '%s' "$BAR_FULL"; else printf '%s' "$BAR_EMPTY"; fi
		i=$((i + 1))
	done
}

# label pct [color] -> "label ▬▬▬▭▭▭▭▭ 42%"
# Without a colour the meter heats up with usage; with one it stays that colour.
meter() {
	if [ -n "${3:-}" ]; then
		label_color="$3"
		fill_color="$3"
	else
		label_color="$C_DIM"
		fill_color="$(heat "$2")"
	fi
	printf '%b%s%b %b%s%b %b%s%%%b' \
		"$label_color" "$1" "$C_OFF" \
		"$fill_color" "$(bar "$2")" "$C_OFF" \
		"$fill_color" "$2" "$C_OFF"
}

# Epoch seconds -> "4h36m" / "36m" of time left, empty once it has passed.
countdown() {
	left=$(($1 - $(date +%s)))
	[ "$left" -le 0 ] && return 0
	h=$((left / 3600))
	m=$(((left % 3600) / 60))
	if [ "$h" -gt 0 ]; then
		printf '%dh%02dm' "$h" "$m"
	else
		printf '%dm' "$m"
	fi
}

# Claude Code keeps every non-empty line of stdout, so context gets a row of
# its own and everything else shares the one below it.
top=""
out=""

# Append to the bottom row, separating from whatever is already there.
add() {
	if [ -z "$out" ]; then
		out="$1"
	else
		out="${out}${SEP}$1"
	fi
}

if [ "$ctx" -ge 0 ]; then
	top=$(meter ctx "$ctx" "$C_CLAUDE")
fi

if [ -n "$dir" ]; then
	pretty=$(printf '%s' "$dir" | sed "s|^${HOME}|~|")
	add "${C_FG}${pretty}${C_OFF}"
fi

if git_dir=$(git -C "${dir:-.}" --no-optional-locks rev-parse --git-dir 2>/dev/null); then
	branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null ||
		git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null || echo "?")

	dirty=""
	if ! git -C "$dir" --no-optional-locks diff --quiet --ignore-submodules HEAD 2>/dev/null; then
		dirty="*"
	fi

	# A linked worktree has its gitdir inside the main repo's worktrees/ dir.
	worktree=""
	case "$git_dir" in
	*/worktrees/*) worktree=" ${C_AQUA}⑂ $(basename "$(git -C "$dir" rev-parse --show-toplevel)")${C_OFF}" ;;
	esac

	add "${C_YELLOW}${branch}${dirty}${C_OFF}${worktree}"
fi

if [ "$session" -ge 0 ]; then
	# Label the window by what is left of it, falling back to its nominal
	# length when the reset time is not reported.
	label="5h"
	if [ "$resets_at" -gt 0 ]; then
		left=$(countdown "$resets_at")
		[ -n "$left" ] && label="$left"
	fi
	add "$(meter "$label" "$session")"
fi

if [ "$week" -ge 0 ]; then
	# The weekly window is too far out for a countdown to be useful, so label
	# it with the reset moment. date(1) renders it in the local timezone.
	label="7d"
	if [ "$week_resets" -gt 0 ]; then
		when=$(date -d "@${week_resets}" +'%a %H:%M' 2>/dev/null || true)
		[ -n "$when" ] && label="$when"
	fi
	add "$(meter "$label" "$week" "$C_FLAMINGO")"
fi

if [ -n "$top" ]; then
	printf '%b\n' "$top"
fi
printf '%b\n' "$out"
