#!/bin/sh
# Depends: base.sh
# Params:
#   - dmd git reference to build (default: dmd-1.x)
set -xe

dmd1_ref="dmd-1.x"
test -n "$1" &&
        dmd1_ref="$1"

# Temporary build directory
cd $(mktemp -d --tmpdir=.)

# Get dmd1 source code
rm -fr dmd
git clone -b "$dmd1_ref" --single-branch --depth 50 \
        https://github.com/dlang/dmd.git
cd dmd

# Build DMD
export VERSION=$(git describe --dirty | cut -c2- |
        sed 's/-\([0-9]\+\)-g\([0-9a-f]\{7\}\)/+\1-\2/' |
        sed 's/\(-[0-9a-f]\{7\}\)-dirty$$/-dirty\1/')

make -C src -f posix.mak

# Make package using MakD
git clone -b v1.9.0 --single-branch --depth 50 \
        https://github.com/sociomantic-tsunami/makd.git

mkdir -p pkg
cat <<EOT > pkg/dmd1.pkg
OPTS = dict(
    name = VAR.name,
    description = "Digital Mars D1 Compiler",
    category = 'devel',
    url = 'https://github.com/dlang/dmd',
    maintainer = 'Leandro Lucarella <leandro.lucarella@sociomantic.com>',
    vendor = 'Sociomantic Labs GmbH',
    license = 'GPLv2',
    depends = ['gcc'] + FUN.autodeps('src/dmd'),
    deb_recommends = 'dmd1-rt',
)

ARGS = [
    "src/dmd=/usr/bin/dmd1",
    "docs/man/man1/dmd.1=/usr/share/man/man1/dmd1.1",
    "docs/man/man5/dmd1.conf.5=/usr/share/man/man5/dmd1.conf.5",
]
EOT

make -f makd/Makd.mak pkg

dpkg -i build/last/pkg/dmd1_*.deb

cd -
rm -fr dmd
