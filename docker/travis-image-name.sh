#!/bin/sh

# Build docker image name
img="sociomantictsunami/$(basename $TRAVIS_REPO_SLUG):ci"
if test "$TRAVIS_PULL_REQUEST" != "false"
then
    echo "$img-$TRAVIS_BRANCH"
else
    echo "$img-$TRAVIS_PULL_REQUEST"
fi
