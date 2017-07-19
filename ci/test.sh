#!/bin/sh
set -xe

DVER=1
if test "$DC" != dmd1; then
	DVER=2
	make -r d2conv
fi

export DC DVER

make -r all
make -r test
