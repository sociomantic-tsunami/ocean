#!/bin/sh
set -xe

img=$(./docker/travis-image-name.sh)

# Run the actual tests
docker run -ti --rm -v "$PWD:$PWD" -w "$PWD" -u "$(id -u)" "$img"  ./docker/travis.sh
