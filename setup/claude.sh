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
for item in CLAUDE.md settings.json keybindings.json agents commands skills output-styles; do
	link "${CLAUDE_SRC}/${item}" "${CLAUDE_DIR}/${item}"
done

echo "Done!"
