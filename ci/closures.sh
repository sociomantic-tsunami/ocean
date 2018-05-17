#!/bin/sh
set -xe

# Env variables needed for `beaver dlang` commands
export DMD=2.071.2.s*
export F=devel
# Enables printing of all potential GC allocation sources to stdout
export DFLAGS=-vgc

# Prepare docker image and sources
beaver dlang install
beaver dlang make d2conv

# Ensure that there are no lines about closure allocations in the output
! beaver dlang make fasttest 2>&1 | grep "closure"
