#!/usr/bin/env bash
#
# Warn when a Bash command edits files by scripted regex replace instead of the
# Edit tool. Reminder only — never blocks.
#
# The hard part is not detection, it is silence. A guard that fires on prose
# (a commit message quoting re.sub) gets ignored within a day, so anything
# whose payload is text rather than code is skipped outright.

cmd=$(jq -r '.tool_input.command // ""')

# Commands whose body is prose, not code. A commit message or PR body may quote
# any idiom below without editing a thing.
case "$cmd" in
*"git commit"*|*"gh pr create"*|*"gh pr edit"*|*"gh issue create"*|*"gh issue comment"*|*"gh pr comment"*)
	exit 0
	;;
esac

fire=0

# In-place stream editors are a scripted replace by definition.
printf '%s' "$cmd" | grep -qiE '(^|[|;&([:space:]])(sed[[:space:]]+(-[a-zA-Z]*i|-i)|perl[[:space:]]+-[a-zA-Z]*(pi|ip))' && fire=1

# An interpreter in COMMAND position (start, or after a pipe/semicolon/&&),
# combined with a substitution idiom anywhere — heredoc bodies span lines, so
# the two are matched independently rather than on one line.
if printf '%s' "$cmd" | grep -qiE '(^|[|;&]|&&|\bthen\b|\bdo\b)[[:space:]]*(python3?|node|ruby|perl)([[:space:]]|$)'; then
	printf '%s' "$cmd" | grep -qE 're\.sub|\.sub\(|\.replace\(|replaceAll|gsub|re\.compile' && fire=1
fi

[ "$fire" = 1 ] || exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"REGEX-REPLACE GUARD. Standing preference: edit files with Edit/Write, not scripted regex replaces. Scripts fail silently, hide the diff, and in this Go tree have repeatedly eaten package qualifiers (db.InnerFoo -> db) and matched identifiers that merely CONTAIN the pattern (closedPositionModel). Before running this, answer: (1) Is this a genuine repo-wide sweep too large for Edit? (2) Have you enumerated the exact hits and will you verify every one after? (3) Does a word boundary or negative lookbehind guard every longer identifier containing your pattern? If any answer is no, use Edit. If you proceed anyway, state in your reply why the sweep was justified."}}
JSON
