.PHONY: build-image run tar 

IMGNAME = debian-dev
DOCKERFILE = test-env/Dockerfile
TOUCHFILE = test-env/.image-done

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


run-pre: $(TOUCHFILE)
	docker run --rm -it $(IMGNAME)


$(TOUCHFILE): $(TARNAME) $(DOCKERFILE) 
	docker build -t $(IMGNAME) -f $(DOCKERFILE) .
	touch $(TOUCHFILE)
