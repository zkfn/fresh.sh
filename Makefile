.PHONY: build-image run-base tar 

IMG_BASE := fresh-test-env:base
IMG_FULL := fresh-test-env:full

DOCKERFILE_BASE = test-env/base.Dockerfile
DOCKERFILE_FULL = test-env/full.Dockerfile

TOUCHFILE_BASE = test-env/.image-base.done
TOUCHFILE_FULL = test-env/.image-full.done

TARNAME = fresh.tar.gz
TAR_TMP_DIR = .tmp/tar

INSTALL_TARS := $(wildcard installs/*.sh)
SETUP_TARS := $(wildcard setup/*.sh)


tar: $(TARNAME) 
build-image: $(TOUCHFILE)


$(TARNAME): testing/ dotfiles/ $(INSTALL_TARS) $(SETUP_TARS) .env.example
	rm -rf $(TAR_TMP_DIR)
	mkdir -p $(TAR_TMP_DIR)
	rsync -aR $(INSTALL_TARS) $(SETUP_TARS) .env.example dotfiles/ testing/ $(TAR_TMP_DIR)
	tar -czvf $(TARNAME) -C $(TAR_TMP_DIR) .


env-base: $(TOUCHFILE_BASE)
	docker run --rm -it $(IMG_BASE)


env-full: $(TOUCHFILE_FULL)
	docker run --rm -it $(IMG_FULL)


$(TOUCHFILE_BASE): $(TARNAME) $(DOCKERFILE_BASE) 
	docker build -t $(IMG_BASE) -f $(DOCKERFILE_BASE) .
	touch $(TOUCHFILE_BASE)


$(TOUCHFILE_FULL): $(TOUCHFILE_BASE) $(TARNAME) $(DOCKERFILE_FULL) 
	docker build -t $(IMG_FULL) -f $(DOCKERFILE_FULL) .
	touch $(TOUCHFILE_FULL)
