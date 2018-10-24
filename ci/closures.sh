#!/bin/bash
set -xe
set -o pipefail

# Enables printing of all potential GC allocation sources to stdout
export DFLAGS=-vgc

# Prepare sources
beaver dlang make d2conv

# Ensure that there are no lines about closure allocations in the output
! beaver dlang make fasttest 2>&1 | grep "closure"
