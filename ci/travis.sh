#!/bin/sh
set -xe

# Defaults (in case they are not set by the CI)
F=${F:-production}
DC=${DC:-dmd1}
DIST=${DIST:-xenial}

DVER=1
if test "$DC" != dmd1; then
	DVER=2
fi

export DC DVER

if test "$DC" != dmd1; then
	make -r d2conv
fi

make -r all
make -r test
