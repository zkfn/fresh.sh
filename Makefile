.PHONY: build-image run

IMGNAME = debian-dev
DOCKERFILE = test-env/Dockerfile
TOUCHFILE = test-env/.image-done

run: $(TOUCHFILE)
	docker run --rm -it $(IMGNAME)

build-image: $(TOUCHFILE)

$(TOUCHFILE): $(DOCKERFILE) 
	docker build -t $(IMGNAME) -f $(DOCKERFILE) .
	touch $(TOUCHFILE)
