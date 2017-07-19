#!/bin/sh
set -xeu
# Binary/package name deduced based on supplied DMD version
case "$DMD" in
    1.*    ) echo "dmd1" ;;
    2.*.s* ) echo "dmd-transitional" ;;
    *      ) echo "dmd" ;;
esac
