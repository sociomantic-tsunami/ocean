#!/bin/sh
set -xe

img=$(./docker/travis-image-name.sh)

# Try to pull the latest image in case we already built this branch/PR
docker pull "$img" || true

# If it was built before, the build will use the cache
docker build -t "$img" docker

# And pushing will also be very fast (done only if there are valid credentials)
set +x # No peeking of password!
if test -n "$DOCKER_PASSWORD"
then
    docker login -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"
    set -x
    docker push "$img"
fi
