#!/bin/sh
set -xe

if [ -z "$1" ]; then
    ref=$1
else
    ref=$(curl -s "https://api.github.com/repos/sociomantic-tsunami/d1to2fix/releases/latest" |
            sed -n 's/^.*"tag_name": "\(.*\)".*$/\1/p')
fi

# Get & build
git clone --depth 50 --branch $ref \
        https://github.com/sociomantic-tsunami/d1to2fix.git
cd d1to2fix
git submodule update --init
make all deb

# Install the resulting package
dpkg -i deb/d1to2fix_*.deb

# Clean up
cd -
rm -fr d1to2fix
