#!/bin/sh
set -xe

git submodule foreach --recursive git submodule deinit --force --all
ci/ci.sh
