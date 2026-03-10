TPM_DIR="${HOME}/.tmux/plugins/tpm"

if [ -d "${TPM_DIR}" ]; then
  echo "TPM already installed, pulling latest..."
  git -C "${TPM_DIR}" pull
else
  echo "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "${TPM_DIR}"
fi

echo "Done!"
