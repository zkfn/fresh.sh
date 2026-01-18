FROM fresh-test-env:base

RUN cp /opt/fresh.sh/.env.example /opt/fresh.sh/.env
RUN /opt/fresh.sh/installs/nvim.sh 2>&1 | tee /tmp/install-nvim.log 

RUN . /opt/fresh.sh/.env && /opt/fresh.sh/setup/git.sh 2>&1 | tee /tmp/setup-git.log 
RUN . /opt/fresh.sh/.env && /opt/fresh.sh/setup/dotfiles.sh 2>&1 | tee /tmp/setup-dotfiles.log 

RUN . /opt/fresh.sh/testing/git-conflict.sh 2>&1 | tee /tmp/testing-git-conflict.log

CMD ["bash"]
