#!/bin/sh
set -xe

if [ -z "$1" ]; then
    ref=$1
else
    ref=$(curl -s "https://api.github.com/repos/sociomantic-tsunami/ebtree/releases/latest" |
            sed -n 's/^.*"tag_name": "\(.*\)".*$/\1/p')
fi

# Get & build
git clone --depth 50 --branch $ref \
        https://github.com/sociomantic-tsunami/ebtree.git
cd ebtree
git submodule update --init
make -r deb

# Install the resulting package
dpkg -i deb/libebtree6_*.deb deb/libebtree6-dev_*.deb

# Clean up
cd -
rm -fr ebtree
