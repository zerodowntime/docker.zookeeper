##
## author: Adam Ćwiertnia <adam.cwiertnia@zdt.io>
##

VERSIONS = 3.5.6

ZOOKEEPER_VERSION ?= $(lastword $(VERSIONS))

IMAGE_NAME ?= zerodowntime/zookeeper
IMAGE_TAG  ?= ${ZOOKEEPER_VERSION}

build: Dockerfile
	docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" \
		--build-arg "ZOOKEEPER_VERSION=${ZOOKEEPER_VERSION}" \
		.

push: build
	docker push "${IMAGE_NAME}:${IMAGE_TAG}"

clean:
	docker image rm "${IMAGE_NAME}:${IMAGE_TAG}"

runit: build
	docker run -it --rm "${IMAGE_NAME}:${IMAGE_TAG}"

inspect: build
	docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}"
