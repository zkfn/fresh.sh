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
	(.transcript_path // ""),
	(.session_id // "")
] | @tsv')

dir=$(printf '%s' "$fields" | cut -f1)
ctx=$(printf '%s' "$fields" | cut -f2)
session=$(printf '%s' "$fields" | cut -f3)
resets_at=$(printf '%s' "$fields" | cut -f4)
week=$(printf '%s' "$fields" | cut -f5)
week_resets=$(printf '%s' "$fields" | cut -f6)
transcript=$(printf '%s' "$fields" | cut -f7)
session_id=$(printf '%s' "$fields" | cut -f8)

# Two sessions on the same tally would otherwise draw the same aside forever.
# The id's first hex group offsets the hash, kept small so the multiply below
# cannot overflow; anything that is not a plain UUID leaves the sequence alone.
TALLY_SEED=0
case "${session_id%%-*}" in
[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
	TALLY_SEED=$((0x${session_id%%-*} % 100000))
	;;
esac

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
a faggot=\bfag(got)?s?\b
a twink=\b(twinks?|twniks?|twikns?|tiwnks?|wtinks?|twinkks?|twiinks?|ttwinks?|twwinks?|twinnks?|twnks?|twiks?)\b
a clanker=\b(clankers?|clunkers?|clankres?|clanekrs?|clakners?|clnakers?|calnkers?|lcankers?|claankers?|cllankers?|clankkers?|klankers?|clankrs?|clankes?)\b'

# The count a tally is scaled against, so it runs green -> yellow -> red on the
# same thresholds as the meters: yellow from half of it, red from 80% of it.
TALLY_FULL=6

# Reads from Claude's side, so "you" is whoever typed and "me" is Claude. The
# pronouns are what fix the direction: without them the row can be read as
# Claude keeping score of the names it called the user.
TALLY_PREFIX='you called me'

# Messages in a row, each with at least one hit, before the streak is shown and
# the count a streak is scaled against.
TALLY_STREAK_MIN=4
TALLY_STREAK_FULL=10

# A long streak gets flanked by flames: the first pair at TALLY_STREAK_FLAME,
# another every TALLY_STREAK_FLAME_STEP after, up to TALLY_STREAK_FLAME_MAX a
# side.
TALLY_STREAK_FLAME=8
TALLY_STREAK_FLAME_STEP=4
TALLY_STREAK_FLAME_MAX=2

# Flames once the session averages this many hits per message, in tenths
# because sh has no floats, and one more flame per further multiple of it.
TALLY_FLAME_AT=8
TALLY_FLAME_MAX=5

# Asides shown now and then, as "placement=text", or "placement@min=text" for
# one that has nothing to say until the tally reaches min:
#   pre    slipped between "you called me" and the list, to qualify the whole
#          accusation before it is made
#   end    appended to the row as it stands, so it brings its own punctuation
#   count  parenthesised after one of the counts, %s being an ordinal drawn
#          from inside that count so it can never name a later one
#   big    slipped in front of a count, and only offered a count large enough
#          for the understatement to land
#   lone   parenthesised after a count small enough to concede, and only when
#          there are enough others to concede it against
#   mono   appended like end, but only when one count has run away with the row
#
# A placement with nothing to land on is dropped before the draw rather than
# after, so the rest still share the odds. big draws per count instead of with
# the row, so several counts can carry one at once. An apostrophe has to be
# written '\'' in this list: it is one single-quoted string.
#   lone   parenthesised after a count small enough to concede, and only once
#          there are enough other counts to concede it against
#
# big and lone draw per count rather than with the row, so several can appear
# at once and alongside whatever the row itself drew. An apostrophe has to be
# written '\'' here: the list is one single-quoted string.
TALLY_JOKES='end=, and i deserved all of it
end=, but who is counting
end=, none of it inaccurate
end=, and the tests still pass
end=, and you should call me more
end@40=, impressive!
pre=(allegedly)
count=(%s one was unfair)
count=(%s one was fair)
big=just
big=only
big=barely
big=merely
big=all of
big=precisely
big=no fewer than
big=a grand total of
lone=(can'\''t object to that one)
mono=, and you should change it up
mono=, how original'

# The count from which "just" reads as understatement rather than description,
# and how often one of those counts gets it. Rolled per count, so this is not
# competing with the row's own aside.
TALLY_JUST_AT=8
TALLY_BIG_CHANCE=25

# A count at or under TALLY_LONE_AT can be conceded, but only with at least
# TALLY_LONE_CROWD counts on the row to concede it against. And one count
# holding TALLY_MONO_AT percent of the row has run away with it.
TALLY_LONE_AT=1
TALLY_LONE_CROWD=3
TALLY_MONO_AT=60

# Percentage of tallies that get an aside: TALLY_JOKE_MIN at a single hit,
# rising in a straight line to TALLY_JOKE_MAX at TALLY_JOKE_FULL of them, and
# level from there on.
TALLY_JOKE_MIN=4
TALLY_JOKE_MAX=50
TALLY_JOKE_FULL=50

# A scattered value from $1, for the choices that have to hold still while the
# tally does. Knuth's multiplicative hash, then an xor-fold: a plain LCG step is
# linear in $1 and its multiplier shares a factor with the modulus, so the low
# digits march rather than scatter, and the fold is what breaks that up.
tally_hash() {
	h=$((($1 + TALLY_SEED) * 2654435761 + 12345))
	h=$(((h / 65536) ^ h))
	printf '%d' $((h % 100000))
}

# 1 -> 1st, 3 -> 3rd, 11 -> 11th, 22 -> 22nd.
ordinal() {
	case $(($1 % 100)) in
	11 | 12 | 13) printf '%dth' "$1" ;;
	*)
		case $(($1 % 10)) in
		1) printf '%dst' "$1" ;;
		2) printf '%dnd' "$1" ;;
		3) printf '%drd' "$1" ;;
		*) printf '%dth' "$1" ;;
		esac
		;;
	esac
}

# The joke for a given tally, or nothing. Keyed to the count in $1 rather than
# drawn at random: the status line redraws on every event, sometimes twice in a
# second, so a per-render coin flip would strobe. This way the line is fixed
# for as long as the tally is, changes the moment it moves, and needs no state
# kept between renders.
tally_joke() {
	h=$(tally_hash "$1")
	skip=$2

	chance=$((TALLY_JOKE_MIN + ($1 - 1) * (TALLY_JOKE_MAX - TALLY_JOKE_MIN) / (TALLY_JOKE_FULL - 1)))
	[ "$chance" -gt "$TALLY_JOKE_MAX" ] && chance=$TALLY_JOKE_MAX
	[ "$chance" -lt "$TALLY_JOKE_MIN" ] && chance=$TALLY_JOKE_MIN

	[ $((h % 100)) -lt "$chance" ] || return 0

	# Drop the lines the tally has not earned yet before drawing, so the ones
	# still in play share the odds evenly rather than losing a turn to a line
	# that had nothing to say.
	earned=$(printf '%s\n' "$TALLY_JOKES" | grep . | grep -Ev "^(${skip})=" | while IFS= read -r line; do
		placement=${line%%=*}
		# The pattern needs its opening paren: inside $( ) an unbalanced one
		# ends the substitution as far as the parser is concerned.
		case "$placement" in
		(*@*) [ "$1" -ge "${placement#*@}" ] || continue ;;
		esac
		printf '%s\n' "$line"
	done)

	count=$(printf '%s\n' "$earned" | grep -c .) || count=0
	[ "$count" -gt 0 ] || return 0
	printf '%s\n' "$earned" | grep . | sed -n "$((h / 100 % count + 1))p"
}

# The understatement for a single count, or nothing. Drawn apart from the row's
# aside and once per count, so a big number can carry one while the row carries
# another, and two big numbers decide for themselves.
tally_big() {
	h=$(tally_hash "$1")

	[ $((h % 100)) -lt "$TALLY_BIG_CHANCE" ] || return 0

	count=$(printf '%s\n' "$TALLY_JOKES" | grep -c '^big=') || count=0
	[ "$count" -gt 0 ] || return 0
	printf '%s\n' "$TALLY_JOKES" | sed -n 's/^big=//p' | sed -n "$((h / 100 % count + 1))p"
}

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
# order, from a single streaming pass over the transcript. What was typed is
# the entries of type user with no toolUseResult; assistant turns and tool
# results are not, so the words only count when they come from the keyboard.
# Task notifications and interrupt markers are injected rather than typed, so
# they are dropped before they can dilute the per-message average.
#
# A message sent mid-turn is logged as a queue-operation, and most of them are
# recorded nowhere else, so those have to be read too or the bulk of what was
# typed during a turn goes uncounted. A few do get mirrored by a user entry a
# few seconds later, though, and reading both counted those twice: doubled word
# counts, and a lone slur passing for a streak. So a queued message is only
# taken when no user entry carries the same text.
tally_scan() {
	jq -rn --argjson words "$2" '
		def typed:
			if .type == "user" and .toolUseResult == null then
				{src: "user", text: (.message.content
					| if type == "string" then . else
						[.[] | select(.type == "text") | .text] | join("\n")
					end)}
			elif .type == "queue-operation" and .operation == "enqueue" then
				{src: "queued", text: .content}
			else
				empty
			end;

		[ inputs
		| typed
		| select(.text | type == "string" and . != "")
		| select(.text | startswith("<") or test("^\\[Request interrupted") | not)
		] as $all

		# How often each text was typed, and how often it was queued. A queued
		# message counts only for the surplus the user entries do not cover, so
		# the mirrored ones are read once and the rest still land.
		| (reduce ($all[] | select(.src == "user") | .text) as $t
			({}; .[$t] = (.[$t] // 0) + 1)) as $mirrored
		| (reduce ($all[] | select(.src == "queued") | .text) as $t
			({}; .[$t] = (.[$t] // 0) + 1)) as $queued
		| (reduce $all[] as $e ({out: [], taken: {}};
			if $e.src == "user" then
				.out += [$e.text]
			elif (.taken[$e.text] // 0)
				< ($queued[$e.text] - ($mirrored[$e.text] // 0)) then
				.out += [$e.text]
				| .taken[$e.text] = (.taken[$e.text] // 0) + 1
			else
				.
			end) | .out) as $msgs
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

	# The counts, in TALLY_WORDS order, so the loop below can walk them rather
	# than re-cut the scan for every word.
	set -- $(printf '%s' "$scan" | cut -f3-)

	total=0
	shown=0
	top=0
	lones=0
	for n in "$@"; do
		if [ "$n" -gt 0 ]; then
			total=$((total + n))
			shown=$((shown + 1))
			[ "$n" -gt "$top" ] && top=$n
			[ "$n" -le "$TALLY_LONE_AT" ] && lones=$((lones + 1))
		fi
	done

	# Placements with nothing to say about this particular row, dropped before
	# the draw. big is always here: it draws per count further down instead.
	skip=big
	[ "$lones" -gt 0 ] && [ "$shown" -ge "$TALLY_LONE_CROWD" ] || skip="${skip}|lone"
	[ "$shown" -ge 2 ] && [ "$total" -gt 0 ] &&
		[ $((top * 100 / total)) -ge "$TALLY_MONO_AT" ] || skip="${skip}|mono"

	joke=$(tally_joke "$total" "$skip")
	kind=${joke%%=*}
	kind=${kind%@*}
	text=${joke#*=}

	# Which count a parenthetical attaches to, counted over the ones its kind
	# is allowed to land on.
	target=0
	case "$kind" in
	count) [ "$shown" -gt 0 ] && target=$(($(tally_hash $((total + 1))) % shown + 1)) ;;
	lone) [ "$lones" -gt 0 ] && target=$(($(tally_hash $((total + 1))) % lones + 1)) ;;
	esac

	# "you called me a retard 4x and a rat 1x", listing only the words used.
	# Only the counts carry colour; the prose around them stays out of the way.
	# One entry is held back so the last one can be joined with "and" rather
	# than a comma.
	names=""
	last=""
	seen=0
	lseen=0
	while IFS='=' read -r label _; do
		[ -n "$label" ] || continue
		n=${1:-0}
		[ $# -gt 0 ] && shift
		if [ "$n" -gt 0 ]; then
			seen=$((seen + 1))
			article=${label%% *}
			word=${label#* }
			hue=$(heat $((n * 100 / TALLY_FULL)))

			# An understatement is its own draw, per count rather than per row,
			# so a big number carries one whether or not the row got an aside
			# and whether or not another count did. It reads as prose, so it
			# stays out of the count's colour.
			just=""
			if [ "$n" -ge "$TALLY_JUST_AT" ]; then
				just=$(tally_big $((total * 100 + seen)))
				[ -n "$just" ] && just="${just} "
			fi

			entry="${C_DIM}${article}${C_OFF} ${hue}${word}${C_OFF} ${C_DIM}${just}${C_OFF}${hue}${n}x${C_OFF}"

			# A parenthetical counts off only the entries its kind may land on,
			# so "lone" reaches the first small count rather than the first
			# count outright. Zero never matches a target, which starts at one.
			tseen=0
			case "$kind" in
			(count) tseen=$seen ;;
			(lone)
				if [ "$n" -le "$TALLY_LONE_AT" ]; then
					lseen=$((lseen + 1))
					tseen=$lseen
				fi
				;;
			esac

			if [ "$tseen" -eq "$target" ]; then
				case "$kind" in
				(count)
					ord=$(ordinal $(($(tally_hash $((total + 2))) % n + 1)))
					entry="${entry} ${C_DIM}${text%\%s*}${ord}${text#*\%s}${C_OFF}"
					;;
				(lone) entry="${entry} ${C_DIM}${text}${C_OFF}" ;;
				esac
			fi

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
		# A qualifier lands before the list, so it colours the accusation
		# rather than any one count.
		pre=""
		[ "$kind" = pre ] && pre="${C_DIM}${text}${C_OFF} "

		tally="${C_DIM}${TALLY_PREFIX}${C_OFF} ${pre}${names}"

		# An aside finishes the sentence the names started, so it goes on before
		# the streak: after it, the comma would read as tying the remark to the
		# streak rather than to the list. The other placements have already
		# been made against their count.
		if [ "$kind" = end ] || [ "$kind" = mono ]; then
			tally="${tally}${C_DIM}${text}${C_OFF}"
		fi

		if [ "$streak" -ge "$TALLY_STREAK_MIN" ]; then
			wings=""
			if [ "$streak" -ge "$TALLY_STREAK_FLAME" ]; then
				sn=$((1 + (streak - TALLY_STREAK_FLAME) / TALLY_STREAK_FLAME_STEP))
				[ "$sn" -gt "$TALLY_STREAK_FLAME_MAX" ] && sn=$TALLY_STREAK_FLAME_MAX
				while [ "$sn" -gt 0 ]; do
					wings="${wings}🔥"
					sn=$((sn - 1))
				done
			fi

			tally="${tally}${C_DIM} · ${C_OFF}${wings:+$wings }${C_DIM}streak${C_OFF}"
			tally="${tally} $(heat $((streak * 100 / TALLY_STREAK_FULL)))${streak}${C_OFF}${wings:+ $wings}"
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
