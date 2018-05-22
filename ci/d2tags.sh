#!/bin/sh
set -xe

# Env variables needed for `beaver dlang install` commands
export DMD=2.071.2.s*
export F=devel

beaver dlang install
beaver dlang d2-release
