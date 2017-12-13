# Copyright sociomantic labs GmbH 2017.
# Distributed under the Boost Software License, Version 1.0.
# (See accompanying file LICENSE.txt or copy at
# http://www.boost.org/LICENSE_1_0.txt)
#
# Utility functions for D build scripts
#
# Use:
#
# . lib/dlang.sh

# Sets the DC and DVER environment variables based on the DMD environment
# variable, if present. The DMD variable is expected to hold the DMD version to
# use:
# For DMD 1.x, DC will be set to dmd1 and DVER to 1.
# For DMD 2.x.y.sN, DC will be set to dmd-transitional and DVER to 2.
# For DMD 2.x.y, DC will be set to dmd and DVER to 2.
# It errors if DMD is not set.
set_dc_dver() {
    old_opts=$-
    set -eu

    # Binary name deduced based on supplied DMD version
    case "$DMD" in
        dmd*   ) DC="$DMD"
                DVER=2
                if test "$DMD" = dmd1
                then
                    DVER=1
                fi
                ;;
        1.*    ) DC=dmd1 DVER=1 ;;
        2.*.s* ) DC=dmd-transitional DVER=2 ;;
        2.*    ) DC=dmd DVER=2 ;;
        *      ) echo "Unknown \$DMD ($DMD)" >&2; false ;;
    esac

    D2_ONLY=false
    if test -r ".D2-ready" && grep -q "^ONLY$" ".D2-ready"
    then
        D2_ONLY=true
    fi

    export DC DVER D2_ONLY
    set $old_opts
}

# Simple function to run commands based on the D version, assuming the `DVER`
# environment variable is set properly.
#
# Example:
#
# if_d 1 dmd1 --version # will run `dmd1 --version` only if DVER == 1
# if_d 2 make -r d2conv # will only run the D2 conversion if DVER == 2
if_d() {
    old_opts=$-
    set -eu

    wanted=$1
    shift
    if test "$DVER" -eq "$wanted"
    then
        "$@"
    fi

    set $old_opts
}

