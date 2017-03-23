#!/bin/sh
set -xe

img=sociomantictsunami/dlang:v1-trusty
docker pull $img
docker run -ti --rm -v "$PWD:$PWD" -w "$PWD" -u "$(id -u)" "$img"  ci/run.sh
