FRESH_SH_DIR="$(cd -- "$(dirname -- "$0")" && cd .. && pwd)"

echo "Located fresh.sh at ${FRESH_SH_DIR}..."

echo "Linking nvim config..."
mkdir -p "${HOME}/.config/"
ln -sf "${FRESH_SH_DIR}/dotfiles/nvim" "${HOME}/.config/nvim"

echo "Linking kitty config..."
mkdir -p "${HOME}/.config/"
ln -sf "${FRESH_SH_DIR}/dotfiles/kitty" "${HOME}/.config/kitty"

echo "Linking starship config..."
ln -sf "${FRESH_SH_DIR}/dotfiles/starship.toml" "${HOME}/.config/starship.toml"

echo "Linking tmux config..."
ln -sf "${FRESH_SH_DIR}/dotfiles/tmux/tmux.conf" "${HOME}/.tmux.conf"

echo "Done!"
