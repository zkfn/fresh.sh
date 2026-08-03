set -eu

FRESH_SH_DIR="$(cd -- "$(dirname -- "$0")" && cd .. && pwd)"
CLAUDE_SRC="${FRESH_SH_DIR}/dotfiles/claude"
CLAUDE_DIR="${HOME}/.claude"

echo "Located fresh.sh at ${FRESH_SH_DIR}..."

# Symlink src -> dest, never clobbering: anything already sitting at dest is
# moved aside to dest.bak (dest.bak.1, dest.bak.2, ... if taken) first.
link() {
	src="$1"
	dest="$2"

	if [ ! -e "$src" ]; then
		return 0
	fi

	if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
		echo "  already linked: ${dest}"
		return 0
	fi

	if [ -e "$dest" ] || [ -L "$dest" ]; then
		bak="${dest}.bak"
		n=1
		while [ -e "$bak" ] || [ -L "$bak" ]; do
			bak="${dest}.bak.${n}"
			n=$((n + 1))
		done
		mv "$dest" "$bak"
		echo "  backed up: ${dest} -> ${bak}"
	fi

	ln -s "$src" "$dest"
	echo "  linked: ${dest}"
}

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
