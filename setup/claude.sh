set -eu

FRESH_SH_DIR="$(cd -- "$(dirname -- "$0")" && cd .. && pwd)"
CLAUDE_SRC="${FRESH_SH_DIR}/dotfiles/claude"
CLAUDE_DIR="${HOME}/.claude"

. "${FRESH_SH_DIR}/setup/lib.sh"

echo "Located fresh.sh at ${FRESH_SH_DIR}..."

echo "Linking claude config..."
mkdir -p "${CLAUDE_DIR}"

# Only the portable parts of ~/.claude. Everything else in there is machine
# state (projects/, history.jsonl, sessions/, .credentials.json, caches) and
# stays put. Items missing from dotfiles/claude are skipped, so adding e.g.
# CLAUDE.md or agents/ to the repo later is enough to get it linked.
for item in CLAUDE.md settings.json keybindings.json statusline.sh agents commands skills output-styles; do
	link "${CLAUDE_SRC}/${item}" "${CLAUDE_DIR}/${item}"
done

# themes/ stays a real directory with the theme files linked into it: Claude
# Code scans it for custom themes and writes into it itself (`/theme` edits),
# and a symlinked directory is not reliably picked up by that scan.
if [ -d "${CLAUDE_SRC}/themes" ]; then
	if [ -L "${CLAUDE_DIR}/themes" ]; then
		# Only ever points into this repo, so nothing to preserve.
		rm "${CLAUDE_DIR}/themes"
		echo "  unlinked: ${CLAUDE_DIR}/themes (replacing with a real directory)"
	fi
	mkdir -p "${CLAUDE_DIR}/themes"
	for theme in "${CLAUDE_SRC}"/themes/*.json; do
		[ -e "$theme" ] || continue
		link "$theme" "${CLAUDE_DIR}/themes/$(basename "$theme")"
	done
fi

echo "Done!"
