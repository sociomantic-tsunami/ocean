#!/bin/sh
set -xe

# Travis likes to fetch submodules recursively, but the build system assumes
# shalow submodules fetching, so we need to remove all the recursive submodules
# before proceeding
git submodule foreach --recursive git submodule deinit --force --all

if_d() {
    wanted=$1
    shift
    if test $DVER -eq $wanted
    then
        "$@"
    fi
}

for DVER in 1 2
do
    if test $DVER = 1; then
        DC=dmd1
    else
        DC=dmd-transitional
    fi
    export DVER DC BUILD_DIR_NAME=build-d$DVER F=production

    xmlfile="$BUILD_DIR_NAME/$F/tmp/unittests.xml"

    if_d 2 \
        make -r d2conv

    make -r all

    make -r test UTFLAGS="-x $xmlfile"

    if_d 2 \
        sed -i 's/classname="/classname="D2./g' $xmlfile
done
