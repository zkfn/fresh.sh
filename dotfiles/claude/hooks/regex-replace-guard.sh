#!/usr/bin/env bash
cmd=$(jq -r '.tool_input.command // ""')
fire=0
# in-place stream editors are always a scripted replace
printf '%s' "$cmd" | grep -qiE 'sed[[:space:]]+(-[a-zA-Z]*i|-i)|perl[[:space:]]+-[a-zA-Z]*(pi|ip)' && fire=1
# an interpreter anywhere in the command PLUS a substitution idiom anywhere (heredocs span lines)
if printf '%s' "$cmd" | grep -qiE '(^|[^a-zA-Z0-9_/-])(python3?|node|ruby|perl)([^a-zA-Z0-9_]|$)'; then
  printf '%s' "$cmd" | grep -qE 're\.sub|\.sub\(|\.replace\(|replaceAll|gsub|re\.compile' && fire=1
fi
[ "$fire" = 1 ] || exit 0
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"REGEX-REPLACE GUARD. Standing preference: edit files with Edit/Write, not scripted regex replaces. Scripts fail silently, hide the diff, and in this Go tree have repeatedly eaten package qualifiers (db.InnerFoo -> db) and matched identifiers that merely CONTAIN the pattern (closedPositionModel). Before running this, answer: (1) Is this a genuine repo-wide sweep too large for Edit? (2) Have you enumerated the exact hits and will you verify every one after? (3) Does a word boundary or negative lookbehind guard every longer identifier containing your pattern? If any answer is no, use Edit. If you proceed anyway, state in your reply why the sweep was justified."}}
JSON
