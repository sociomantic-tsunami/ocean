#!/bin/sh
set -xe

if [ -z "$1" ]; then
    ref=$1
else
    ref=$(curl -s "https://api.github.com/repos/sociomantic-tsunami/tangort/releases/latest" |
            sed -n 's/^.*"tag_name": "\(.*\)".*$/\1/p')
fi

# Get & build
git clone --depth 50 --branch $ref \
        https://github.com/sociomantic-tsunami/tangort.git
cd tangort
git submodule update --init
make -r pkg

# Install the resulting package
dpkg -i build/last/pkg/libtangort-dmd-dev_*.deb

# Clean up
cd -
rm -fr tangort
