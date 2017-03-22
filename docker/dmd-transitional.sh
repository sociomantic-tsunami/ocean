#!/bin/sh
# Depends: base.sh
# Params:
#   - dmd-bin package version (default: latest)
set -xe

dmd_version=""
test -n "$1" &&
        dmd_version="$1"

PATCH_DIR=$PWD/dmd-transitional/patches

# Temporary build directory
cd $(mktemp -d --tmpdir=.)

# Build dmd-transitional from source
git clone -b "$dmd_version" --single-branch --depth 50 \
        https://github.com/dlang/dmd.git
cd dmd

# Calculate version (so it doesn't get dirtied)
export VERSION=$(git describe --dirty | cut -c2- |
        sed 's/-\([0-9]\+\)-g\([0-9a-f]\{7\}\)/+\1-\2/' |
        sed 's/\(-[0-9a-f]\{7\}\)-dirty$$/-dirty\1/')

# Patch and build DMD
git apply $PATCH_DIR/dmd/*.patch
make -r -f posix.mak MODEL=64 RELEASE=1

# Fetch, patch and build druntime
git clone -b "$dmd_version" --single-branch --depth 50 \
        https://github.com/dlang/druntime.git
cd druntime
git apply $PATCH_DIR/druntime/*.patch
make -r -f posix.mak MODEL=64 DMD=../src/dmd BUILD=debug
make -r -f posix.mak MODEL=64 DMD=../src/dmd BUILD=release
cd -

# Fetch and build phobos
#git clone -b "$dmd_version" --single-branch --depth 50 \
#        https://github.com/dlang/phobos.git
#make -r -C phobos -f posix.mak MODEL=64 RELEASE=1

# Make package using MakD
git clone -b v1.9.0 --single-branch --depth 50 \
        https://github.com/sociomantic-tsunami/makd.git

cat <<EOT > dmd.conf
[Environment]
DFLAGS=-I/usr/include/d2/dmd-transitional -L--export-dynamic -defaultlib=druntime -debuglib=druntime-dbg -version=GLIBC
EOT

mkdir -p pkg
cat <<EOT > pkg/dmd-transitional.pkg
OPTS = dict(
    name = VAR.name,
    description = "Digital Mars Transitional D2 Compiler",
    category = 'devel',
    url = 'https://github.com/dlang/dmd',
    maintainer = 'Leandro Lucarella <leandro.lucarella@sociomantic.com>',
    vendor = 'Sociomantic Labs GmbH',
    license = 'proprietary',
    depends = ['gcc'] + FUN.autodeps('src/dmd'),
)

ARGS = [
    "dmd.conf=/etc/dmd-transitional.conf",
    "src/dmd=/usr/bin/dmd-transitional",
    "docs/man/man1/dmd.1=/usr/share/man/man1/dmd-transitional.1",
    "docs/man/man5/dmd.conf.5=/usr/share/man/man5/dmd-transitional.conf.5",
    "druntime/generated/linux/release/64/libdruntime.a=/usr/lib/libdruntime.a",
    "druntime/generated/linux/debug/64/libdruntime.a=/usr/lib/libdruntime-dbg.a",
    "druntime/import/=usr/include/d2/dmd-transitional",
]
EOT


make -f makd/Makd.mak pkg

dpkg -i build/last/pkg/dmd-transitional_*.deb

cd -
rm -fr dmd
