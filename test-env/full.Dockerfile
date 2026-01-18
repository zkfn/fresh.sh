FROM fresh-test-env:base

COPY fresh.tar.gz /tmp/
RUN mkdir -p /opt/fresh.sh && tar -xzvf /tmp/fresh.tar.gz -C /opt/fresh.sh && rm /tmp/fresh.tar.gz
RUN /opt/fresh.sh/installs/nvim.sh 2>&1 | tee /tmp/install-nvim.log 

CMD ["bash"]
