#!/bin/sh
set -xe

img=$(ci/travis-image-name.sh)

# Run the actual tests
docker run -ti --rm -v "$PWD:$PWD" -w "$PWD" -u "$(id -u)" "$img"  ci/travis.sh
