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

COPY fresh.tar.gz /tmp/
RUN mkdir -p /opt/fresh.sh && tar -xzvf /tmp/fresh.tar.gz -C /opt/fresh.sh && rm /tmp/fresh.tar.gz

CMD ["bash"]
