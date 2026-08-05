#!/bin/sh
# Claude Code status line. Reads the session JSON on stdin, prints up to three
# rows: dir (+ worktree) and branch; context, session and weekly meters; and
# the tally of what the session has called Claude.
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
	(.rate_limits.seven_day.resets_at // -1 | floor),
	(.transcript_path // "")
] | @tsv')

dir=$(printf '%s' "$fields" | cut -f1)
ctx=$(printf '%s' "$fields" | cut -f2)
session=$(printf '%s' "$fields" | cut -f3)
resets_at=$(printf '%s' "$fields" | cut -f4)
week=$(printf '%s' "$fields" | cut -f5)
week_resets=$(printf '%s' "$fields" | cut -f6)
transcript=$(printf '%s' "$fields" | cut -f7)

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

# One "label=regex" per line. The label carries its own article so that adding
# e.g. "an idiot" still reads right. The regex is Oniguruma, applied by jq
# case-insensitively; \b behaves the same there on every platform, unlike in
# BSD and GNU grep. "rat" and "fag" need those boundaries or they fire on
# "separate" and "flags"; "retard" is left unanchored so that "retarded" and
# "retards" count too, and carries the transpositions and dropped letters that
# typing it in a hurry produces.
TALLY_WORDS='a retard=retard|retrad|retadr|retatd|retartd|retaard|reatrd|reetard|ratard|rtard|retarted
a rat=\brat\b
a faggot=\bfag(got)?s?\b'

# The count a tally is scaled against, so it runs green -> yellow -> red on the
# same thresholds as the meters: yellow from half of it, red from 80% of it.
TALLY_FULL=6

# Reads from Claude's side, so "you" is whoever typed and "me" is Claude. The
# pronouns are what fix the direction: without them the row can be read as
# Claude keeping score of the names it called the user.
TALLY_PREFIX='you called me'

# Messages in a row, each with at least one hit, before the streak is shown and
# the count a streak is scaled against.
TALLY_STREAK_MIN=2
TALLY_STREAK_FULL=5

# Flames once the session averages this many hits per message, in tenths
# because sh has no floats, and one more flame per further multiple of it.
TALLY_FLAME_AT=8
TALLY_FLAME_MAX=5

# TALLY_WORDS as JSON, for the scan below to iterate.
tally_words() {
	printf '%s\n' "$TALLY_WORDS" | jq -Rn '[
		inputs
		| select(length > 0)
		| split("=")
		| {label: .[0], re: (.[1:] | join("="))}
	]'
}

# "messages<TAB>streak<TAB>count..." with one count per word in TALLY_WORDS
# order, from a single streaming pass over the transcript. Prompts are entries
# of type user with no toolUseResult; anything sent while a turn is running is
# only ever recorded as queued content, so both are read. Assistant turns and
# tool results are not, so the words only count when they come from the
# keyboard. Task notifications and interrupt markers are injected rather than
# typed, so they are dropped before they can dilute the per-message average.
tally_scan() {
	jq -rn --argjson words "$2" '
		def typed:
			if .type == "user" and .toolUseResult == null then
				.message.content
				| if type == "string" then . else
					[.[] | select(.type == "text") | .text] | join("\n")
				end
			elif .type == "queue-operation" and .operation == "enqueue" then
				.content
			else
				empty
			end;

		[ inputs
		| typed
		| select(type == "string" and . != "")
		| select(startswith("<") or test("^\\[Request interrupted") | not)
		] as $msgs
		| [$msgs[] as $m | [$words[] | .re as $re | $m | [match($re; "gi")] | length]] as $hits
		| [
			($msgs | length),
			($hits | reverse | map(add > 0) | (index(false) // length))
		]
		+ [range(0; $words | length) as $i | $hits | map(.[$i]) | add // 0]
		| @tsv
	' "$1" 2>/dev/null
}

# Claude Code keeps every non-empty line of stdout: location gets the top row,
# the meters the one below it, the tally the one below that.
location=""
meters=""
tally=""

# Meters sit side by side on the lower row, separated by whitespace alone.
add_meter() {
	if [ -z "$meters" ]; then
		meters="$1"
	else
		meters="${meters}  $1"
	fi
}

# Append to the location row, separating from whatever is already there.
add() {
	if [ -z "$location" ]; then
		location="$1"
	else
		location="${location}${SEP}$1"
	fi
}

if [ "$ctx" -ge 0 ]; then
	add_meter "$(meter ctx "$ctx" "$C_CLAUDE")"
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

if [ -n "$transcript" ] && [ -f "$transcript" ]; then
	scan=$(tally_scan "$transcript" "$(tally_words)")
	msgs=$(printf '%s' "$scan" | cut -f1)
	streak=$(printf '%s' "$scan" | cut -f2)
	[ -n "$msgs" ] || msgs=0
	[ -n "$streak" ] || streak=0

	# "you called me a retard 4x and a rat 1x", listing only the words used.
	# Only the counts carry colour; the prose around them stays out of the way.
	# One entry is held back so the last one can be joined with "and" rather
	# than a comma.
	names=""
	last=""
	total=0
	shown=0
	field=2
	while IFS='=' read -r label _; do
		[ -n "$label" ] || continue
		field=$((field + 1))
		n=$(printf '%s' "$scan" | cut -f"$field")
		[ -n "$n" ] || n=0
		if [ "$n" -gt 0 ]; then
			total=$((total + n))
			shown=$((shown + 1))
			article=${label%% *}
			word=${label#* }
			entry="${C_DIM}${article}${C_OFF} $(heat $((n * 100 / TALLY_FULL)))${word} ${n}x${C_OFF}"
			if [ -n "$last" ]; then
				names="${names:+${names}${C_DIM},${C_OFF} }${last}"
			fi
			last="$entry"
		fi
	done <<EOF
$TALLY_WORDS
EOF

	# Two items get a bare "and", three or more keep the serial comma.
	if [ "$shown" -ge 3 ]; then
		names="${names}${C_DIM}, and${C_OFF} ${last}"
	elif [ "$shown" -eq 2 ]; then
		names="${names}${C_DIM} and${C_OFF} ${last}"
	else
		names="$last"
	fi

	if [ -n "$names" ]; then
		tally="${C_DIM}${TALLY_PREFIX}${C_OFF} ${names}"

		if [ "$streak" -ge "$TALLY_STREAK_MIN" ]; then
			tally="${tally}${C_DIM} · streak${C_OFF} $(heat $((streak * 100 / TALLY_STREAK_FULL)))${streak}${C_OFF}"
		fi

		# Flames lead the row, one per multiple of the average threshold.
		if [ "$msgs" -gt 0 ]; then
			n=$(((total * 10 / msgs) / TALLY_FLAME_AT))
			[ "$n" -gt "$TALLY_FLAME_MAX" ] && n=$TALLY_FLAME_MAX
			flames=""
			while [ "$n" -gt 0 ]; do
				flames="${flames}🔥"
				n=$((n - 1))
			done
			[ -n "$flames" ] && tally="${flames} ${tally}"
		fi
	fi
fi

if [ "$session" -ge 0 ]; then
	# Label the window by what is left of it, falling back to its nominal
	# length when the reset time is not reported.
	label="5h"
	if [ "$resets_at" -gt 0 ]; then
		left=$(countdown "$resets_at")
		[ -n "$left" ] && label="$left"
	fi
	add_meter "$(meter "$label" "$session")"
fi

if [ "$week" -ge 0 ]; then
	# The weekly window is too far out for a countdown to be useful, so label
	# it with the reset moment. date(1) renders it in the local timezone.
	label="7d"
	if [ "$week_resets" -gt 0 ]; then
		when=$(date -d "@${week_resets}" +'%a %H:%M' 2>/dev/null || true)
		[ -n "$when" ] && label="$when"
	fi
	add_meter "$(meter "$label" "$week" "$C_FLAMINGO")"
fi

if [ -n "$location" ]; then
	printf '%b\n' "$location"
fi
printf '%b\n' "$meters"
if [ -n "$tally" ]; then
	printf '%b\n' "$tally"
fi
