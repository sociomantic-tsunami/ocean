#!/bin/sh
set -xeu

# Package name deduced based on supplied DMD version
case "$DMD" in
    dmd*   ) DMD_PKG= ;;
    1.*    ) DMD_PKG="dmd1=$DMD" ;;
    2.*.s* ) DMD_PKG="dmd-transitional=$DMD" ;;
    2.*    ) DMD_PKG="dmd-bin=$DMD libphobos2-dev=$DMD" ;;
    *      ) echo "Unknown \$DMD ($DMD)" >&2; exit 1 ;;
esac

export DMD_PKG
