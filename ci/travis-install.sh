#!/bin/sh
set -xe

# Build the docker image.
docker build --pull -t ocean .
