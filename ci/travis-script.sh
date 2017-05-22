#!/bin/sh
set -xe

# Run the actual tests
docker run -ti --rm -v "$PWD:$PWD" -w "$PWD" -u "$(id -u)" \
	-e "DIST=$DIST" -e "DC=$DC" -e "F=$F" \
	ocean:$DIST ci/travis.sh
