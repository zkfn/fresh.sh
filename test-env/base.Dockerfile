FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
	bash \
    ca-certificates \
	curl \
	gh \
    git \
    tmux \
    zsh \
 && rm -rf /var/lib/apt/lists/*

CMD ["bash"]
