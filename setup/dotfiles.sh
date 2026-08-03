set -eu

FRESH_SH_DIR="$(cd -- "$(dirname -- "$0")" && cd .. && pwd)"

. "${FRESH_SH_DIR}/setup/lib.sh"

echo "Located fresh.sh at ${FRESH_SH_DIR}..."

mkdir -p "${HOME}/.config/"

echo "Linking nvim config..."
link "${FRESH_SH_DIR}/dotfiles/nvim" "${HOME}/.config/nvim"

echo "Linking kitty config..."
link "${FRESH_SH_DIR}/dotfiles/kitty" "${HOME}/.config/kitty"

echo "Linking starship config..."
link "${FRESH_SH_DIR}/dotfiles/starship.toml" "${HOME}/.config/starship.toml"

echo "Linking tmux config..."
link "${FRESH_SH_DIR}/dotfiles/tmux/tmux.conf" "${HOME}/.tmux.conf"
link "${FRESH_SH_DIR}/dotfiles/tmux" "${HOME}/.config/tmux"

echo "Done!"
