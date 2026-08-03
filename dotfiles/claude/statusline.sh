#!/bin/sh
# Claude Code status line. Reads the session JSON on stdin, prints one line.
# Shows: dir (+ worktree), branch, context usage, 5h session usage bar.
set -eu

# gruvbox-material, matching the tmux status bar
C_DIM='\033[38;2;146;131;116m'
C_FG='\033[38;2;221;199;161m'
C_YELLOW='\033[38;2;216;166;87m'
C_AQUA='\033[38;2;125;174;163m'
C_RED='\033[38;2;234;105;98m'
C_OFF='\033[0m'

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
	printf '%s\n' "${PWD}"
	exit 0
fi

# -1 stands in for "not reported yet", which happens on the first render.
fields=$(printf '%s' "$input" | jq -r '[
	(.workspace.current_dir // .cwd // ""),
	(.context_window.used_percentage // -1 | floor),
	(.rate_limits.five_hour.used_percentage // -1 | floor)
] | @tsv')

dir=$(printf '%s' "$fields" | cut -f1)
ctx=$(printf '%s' "$fields" | cut -f2)
session=$(printf '%s' "$fields" | cut -f3)

# Colour by how close to full something is.
heat() {
	if [ "$1" -ge 80 ]; then
		printf '%b' "$C_RED"
	elif [ "$1" -ge 50 ]; then
		printf '%b' "$C_YELLOW"
	else
		printf '%b' "$C_AQUA"
	fi
}

# 5-cell bar, one cell per 20%.
bar() {
	filled=$(($1 / 20))
	[ "$filled" -gt 5 ] && filled=5
	i=0
	while [ "$i" -lt 5 ]; do
		if [ "$i" -lt "$filled" ]; then printf '▰'; else printf '▱'; fi
		i=$((i + 1))
	done
}

out=""

if [ -n "$dir" ]; then
	pretty=$(printf '%s' "$dir" | sed "s|^${HOME}|~|")
	out="${C_FG}${pretty}${C_OFF}"
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
	*/worktrees/*) worktree=" ${C_DIM}⑂$(basename "$(git -C "$dir" rev-parse --show-toplevel)")${C_OFF}" ;;
	esac

	out="${out} ${C_YELLOW}${branch}${dirty}${C_OFF}${worktree}"
fi

if [ "$ctx" -ge 0 ]; then
	out="${out} ${C_DIM}ctx${C_OFF} $(heat "$ctx")${ctx}%${C_OFF}"
fi

if [ "$session" -ge 0 ]; then
	out="${out} ${C_DIM}5h${C_OFF} $(heat "$session")$(bar "$session")${C_OFF} $(heat "$session")${session}%${C_OFF}"
fi

printf '%b\n' "$out"
