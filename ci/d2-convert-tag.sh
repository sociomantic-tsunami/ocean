#!/bin/sh
set -xe

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
		push "https://github.com/sociomantic-tsunami/ocean.git" "$d2tag"
fi
