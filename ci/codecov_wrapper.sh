set -eu

. submodules/beaver/lib/dlang.sh
set_dc_dver

# Export any codecov-specific environment variable
codecov_vars="$(printenv -0 | sed -zn 's/^\(CODECOV_[^=]\+\)=.*$/\1\n/p' |
        tr -d '\0')"
# Export D related environment variables
dlang_vars="DIST DMD DC DVER D2_ONLY F V"
export BEAVER_DOCKER_VARS="${BEAVER_DOCKER_VARS:-} $codecov_vars $dlang_vars"

beaver run ci/codecov.sh
