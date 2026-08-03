# Shared helpers for the setup scripts. Source it, don't run it:
#   . "${FRESH_SH_DIR}/setup/lib.sh"

# Symlink src -> dest, never clobbering: anything already sitting at dest is
# moved aside to dest.bak (dest.bak.1, dest.bak.2, ... if taken) first. A dest
# that is already the right symlink is left alone, so re-runs are no-ops.
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
