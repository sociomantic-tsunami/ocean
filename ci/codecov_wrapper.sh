set -eu

. submodules/beaver/lib/dlang.sh
set_dc_dver

# Export any codecov-specific environment variable
codecov_vars="$(printenv -0 | sed -zn 's/^\(CODECOV_[^=]\+\)=.*$/\1\n/p' |
        tr -d '\0')"
# Export D related environment variables
dlang_vars="DIST DMD DC DVER D2_ONLY F V"
export BEAVER_DOCKER_VARS="${BEAVER_DOCKER_VARS:-} $codecov_vars $dlang_vars"

# Copy coverage reports and git structure to a clean directory
tmp=`mktemp -d`
trap 'r=$?; rm -fr "$tmp"; exit $r' EXIT INT TERM QUIT
mkdir -p "$tmp/reports"
cp -a .*.lst "$tmp/reports"
git archive --format=tar HEAD | (cd "$tmp" && tar xf -)
cp -a .git "$tmp/"
cp -av "ci/codecov.sh" "$tmp/codecov"

cd $tmp
beaver run ./codecov.sh -n beaver -s reports -e DIST,DMD,DC,F -X gcov -X \
    coveragepy -X xcode
