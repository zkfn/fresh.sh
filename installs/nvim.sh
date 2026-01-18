if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

echo "Detected $(OS) / $(ARCH)"

case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64)
        NVIM="nvim-linux-x86_64"
        ;;
      aarch64|arm64)
        NVIM="nvim-linux-arm64"
        ;;
      *)
        echo "Unsupported Linux architecture: $ARCH" >&2
        exit 1
        ;;
    esac
    ;;
  Darwin)
    case "$ARCH" in
      x86_64)
        NVIM="nvim-macos-x86_64"
        ;;
      arm64)
        NVIM="nvim-macos-arm64"
        ;;
      *)
        echo "Unsupported macOS architecture: $ARCH" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

NVIM_TAR="$(NVIM).tar.gz"

echo "Downloading nightly version of $(NVIM_TAR)..."
NVIM_URL="https://github.com/neovim/neovim/releases/download/nightly/$(NVIM_TAR)"

echo "Unpacking..."
curl -LO $(NVIM_URL)
rm -rf /opt/$(NVIM)
tar -C /opt -xzf $(NVIM_TAR)

echo "Linking exectuable..."
ln -sf "/opt/$NVIM_DIR/bin/nvim" /usr/local/bin/nvim

echo "Done!"
