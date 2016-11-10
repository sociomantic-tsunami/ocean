#!/bin/sh
# Depends: base.sh
# Params:
#   - dmd-bin package version (default: latest)
set -xe

dmd_version=""
test -n "$1" &&
        dmd_version="=$1"

# Install D-APT packages
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EBCF975E5BA24D5E && \
        wget http://master.dl.sourceforge.net/project/d-apt/files/d-apt.list \
            -O /etc/apt/sources.list.d/d-apt.list

# Make sure our packages list is updated
apt-get update

# Install dmd-bin
apt-get install -y dmd-bin$dmd_version libphobos2-dev$dmd_version
