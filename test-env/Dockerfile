FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
	bash \
    ca-certificates \
	gh \
    git \
    neovim \
    tmux \
    zsh \
 && rm -rf /var/lib/apt/lists/*

COPY . /opt/fresh.sh

RUN chmod +x /opt/fresh.sh/installs/*.sh 
RUN /opt/fresh.sh/installs/nvim.sh

CMD ["bash"]
