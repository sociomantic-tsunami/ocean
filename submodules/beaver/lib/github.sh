# Copyright sociomantic labs GmbH 2017.
# Distributed under the Boost Software License, Version 1.0.
# (See accompanying file LICENSE.txt or copy at
# http://www.boost.org/LICENSE_1_0.txt)
#
# This is a sh library with utilities for interacting with GitHub.
#
# Use:
#
# . lib/github.sh

# Performs a GitHub API call
#
# The first argument is the method to use, the second is the URI (like
# /repos"). The third argument is optional and it should contain a GitHub OAuth
# token if auth is needed by the request. Alternatively the token will be taken
# from the environment variable "$GITHUB_OAUTH_TOKEN" if not present as an
# argument.
#
# If there is input in stdin, then it will be sent as HTTP payload in the
# request.
github_api()
{
    ( { set +x -ue; } 2>/dev/null # disable verboseness (silently)

    method=$1
    uri=$2
    token=${3:-${GITHUB_OAUTH_TOKEN}}

    # Use \n as argument separator to avoid problems with spaces
    curl_args="-X\n$method\n-H\nContent-Type:application/json"

    # If we have a token, use it
    if test -n "${token:-}"
    then
        curl_args="$curl_args\n-H\nAuthorization: token $token"
    fi

    # If we have data via stdin, send it as the request data
    data_file=$(mktemp)
    cat > "$data_file"
    if test -s "$data_file"
    then
        curl_args="$curl_args\n-d\n@$data_file"
        ( set -x; cat "$data_file" )
    fi

    curl_args="$curl_args\nhttps://api.github.com$uri"

    # Send the request
    printf -- "$curl_args" | xargs -td'\n' curl

    # Remove temporary data file
    rm -f "$data_file"

    )
}
