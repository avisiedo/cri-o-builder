
IMG ?= quay.io/avisied0/demos:cri-o

.PHONY: login
login:: ## Do login into registry.ci.openshift.org
	podman login registry.ci.openshift.org

.PHONY: build
build:: ## Build the container image
	#podman build -t $(IMG) -f images/os/Dockerfile.build-ubi8
	podman build -t $(IMG) -f Dockerfile .

.PHONY: push
push:: ## Push the image to the container image registry
	podman push $(IMG)

.PHONY: shell
shell:: ## Open a shell inside the container for debugging
	podman run -it -v "$(PWD):/src:z" -w /src $(IMG) bash

.PHONY: help
help:

