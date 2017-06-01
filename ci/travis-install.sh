#!/bin/sh
set -xe

mkdir -p /tmp/docker-cache
signature_file="/tmp/docker-cache/signature.txt"
image_file="/tmp/docker-cache/ocean.tar.gz"

cached=no

# Check for docker signature
if test -f "$signature_file"
then
    old_sig=$(cat $signature_file)
    new_sig=$(find Dockerfile docker -type f | xargs cat | sha256sum)
    if test "$new_sig" = "$old_sig"
    then
        cached=yes
        zcat "$image_file" |
            time -f 'Load took %es\n' docker load -q
    fi
fi

if test "$cached" = "no"
then
    # Build the docker image.
    time -f 'Build took %es\n' docker build --pull -t ocean .

     # Write/update the signature file
    find Dockerfile docker -type f | xargs cat | sha256sum > "$signature_file"

    # Write/update the image cache
    docker images --all --format '{{.Repository}}:{{.Tag}} {{.ID}}' |
        sed 's|<none>:<none>||g' |
        time -f 'Save took %es\n' xargs docker save |
        gzip --fast > "$image_file"
fi
