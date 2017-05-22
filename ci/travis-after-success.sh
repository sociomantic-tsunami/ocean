#!/bin/sh
set -xe

# Submit code coverage report
mkdir coverage
cp .codecov.yml coverage/
cp ci/codecov.sh coverage/
find . -maxdepth 1 -type f -name "*.lst" -exec mv '{}' 'coverage/' \;
git_commit=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
CODECOVCMD="codecov.sh -y .codecov.yml -R ."
docker run -ti --rm -v $PWD/coverage:/docker -w /docker \
    -e CI \
    -e TRAVIS -e TRAVIS_BRANCH -e TRAVIS_COMMIT -e TRAVIS_JOB_NUMBER \
    -e TRAVIS_PULL_REQUEST -e TRAVIS_JOB_ID -e TRAVIS_REPO_SLUG -e TRAVIS_TAG \
    -e TRAVIS_OS_NAME -e TRAVIS_PULL_REQUEST_BRANCH -e TRAVIS_PULL_REQUEST_SHA \
    ocean bash $CODECOVCMD

# If this is a tag, convert and push to ocean-d2 repo
if test -n "$TRAVIS_TAG"
then
	# First clean all in the repository to make sure we have a clean start
	git reset --hard
	git clean -fdx
	# Convert the code
	make -r d2conv
	# Add dub.sdl
	cp -v ci/ocean-d2-dub.sdl dub.sdl
	git add dub.sdl
	# Commit the changes and tag
	git config user.name="Sociomantic Travis Bot"
	git config user.email="tsunami@sociomantic.com"
	git commit -a -m 'Auto-convert to D2'
	# Create the new tag
	d2tag=$TRAVIS_TAG+d2.auto
	git tag -m "$TRAVIS_TAG auto-converted to D2, see https://github.com/sociomantic-tsunami/ocean/releases/tag/$TRAVIS_TAG" "$d2tag"
	# Push (making sure the credentials are not leaked and using a helper
	# to get the password)
	set +x
	git -c "credential.https://github.com.username=${OCEAN_D2_USER}" \
		-c "core.askPass=./ci/askpass.sh" \
		push "https://github.com/sociomantic-tsunami/ocean-d2.git" "$d2tag"
fi
