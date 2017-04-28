#!/bin/sh
set -xe

# Run the actual tests
docker run -ti --rm -v "$PWD:$PWD" -w "$PWD" -u "$(id -u)" ocean ci/travis.sh
