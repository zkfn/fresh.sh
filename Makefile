.PHONY: build-image run-base tar 

IMG_BASE := fresh-test-env:base
IMG_FULL := fresh-test-env:full
CTR_NAME := fresh-dev

DOCKERFILE_BASE = test-env/base.Dockerfile
DOCKERFILE_FULL = test-env/full.Dockerfile

TOUCHFILE_BASE = test-env/.image-base.done
TOUCHFILE_FULL = test-env/.image-full.done

TARNAME = fresh.tar.gz
INSTALL_TARS := $(wildcard installs/*.sh)
TAR_TMP_DIR = .tmp/tar



tar: $(TARNAME) 
build-image: $(TOUCHFILE)


$(TARNAME): $(INSTALL_TARS)
	rm -rf $(TAR_TMP_DIR)
	mkdir -p $(TAR_TMP_DIR)
	rsync -R $(INSTALL_TARS) $(TAR_TMP_DIR)
	tar -czvf $(TARNAME) -C $(TAR_TMP_DIR) .


env-base: $(TOUCHFILE_BASE)
	docker run --rm -it $(IMG_BASE)


env-full: $(TOUCHFILE_FULL)
	docker run --rm -it $(IMG_FULL)


$(TOUCHFILE_BASE): $(DOCKERFILE_BASE) 
	docker build -t $(IMG_BASE) -f $(DOCKERFILE_BASE) .
	touch $(TOUCHFILE_BASE)


$(TOUCHFILE_FULL): $(TOUCHFILE_BASE) $(TARNAME) $(DOCKERFILE_FULL) 
	docker build -t $(IMG_FULL) -f $(DOCKERFILE_FULL) .
	touch $(TOUCHFILE_FULL)
