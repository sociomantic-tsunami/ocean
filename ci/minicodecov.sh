#!/bin/bash
# Based on https://github.com/codecov/codecov-bash
set -xeu

# Use general dlang utilities
. $(git config -f .gitmodules submodule.beaver.path)/lib/dlang.sh

# Set the DC and DVER environment variables and export them to docker
set_dc_dver

upload_file=`mktemp /tmp/minicodecov.XXXXXX`

env="DIST DMD DC DVER D2_ONLY"
for v in $env
do
    echo "$v=$(eval echo "\$$v")" >> $upload_file
done
echo "<<<<<< ENV" >> $upload_file

#network=$(git ls-files)
#if [ "$ft_network" == "1" ];
#then
#  i="woff|eot|otf"  # fonts
#  i="$i|gif|png|jpg|jpeg|psd"  # images
#  i="$i|ptt|pptx|numbers|pages|md|txt|xlsx|docx|doc|pdf"  # docs
#  i="$i|yml|yaml|.gitignore"  # supporting docs
#  echo "$network" | grep -vwE "($i)$" >> $upload_file
#  echo "<<<<<< network" >> $upload_file
#fi

find build/last/cov -type f -name '*.lst' | while read -r file
do
    # append to to upload
    echo "# path=$file" >> $upload_file
    cat "$file" >> $upload_file
    echo "<<<<<< EOF" >> $upload_file
done

urlencode() {
  echo "$1" | curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" | cut -c 3- | sed -e 's/%0A//'
}

query="package=beaver\
       &token=\
       &branch=$TRAVIS_BRANCH\
       &commit=$TRAVIS_COMMIT\
       &build=$TRAVIS_JOB_NUMBER\
       &build_url=$(urlencode "https://travis-ci.org/$TRAVIS_REPO_SLUG/builds/$TRAVIS_BUILD_ID")\
       &name=\
       &tag=$TRAVIS_TAG\
       &slug=$TRAVIS_REPO_SLUG\
       &yaml=$(urlencode ".codecov.yml")\
       &service=travis\
       &flags=\
       &pr=${TRAVIS_PULL_REQUEST##\#}\
       &job=$TRAVIS_JOB_ID"

query=$(echo "${query}" | tr -d ' ')

i="0"
while [ $i -lt 4 ]
do
  i=$[$i+1]
  res=$(curl -X POST $curlargs $cacert "$url/upload/v4?$query" -H 'Accept: text/plain' || true)
  # a good replay is "https://codecov.io" + "\n" + "https://codecov.s3.amazonaws.com/..."
  status=$(echo "$res" | head -1 | grep 'HTTP ' | cut -d' ' -f2)
  if [ "$status" = "" ];
  then
    s3target=$(echo "$res" | sed -n 2p)
    say "    ${e}->${x} Uploading to S3 $(echo "$s3target" | cut -c1-32)"
    s3=$(curl -fiX PUT $curlawsargs \
              --data-binary @$upload_file \
              -H 'Content-Type: text/plain' \
              -H 'x-amz-acl: public-read' \
              -H 'x-amz-storage-class: REDUCED_REDUNDANCY' \
              "$s3target" || true)
    if [ "$s3" != "" ];
    then
      say "    ${g}->${x} View reports at ${b}$(echo "$res" | sed -n 1p)${x}"
      exit 0
    else
      say "    ${r}X>${x} Failed to upload to S3"
    fi
  elif [ "$status" = "400" ];
  then
      # 400 Error
      say "${g}${res}${x}"
      exit ${exit_with}
  fi
  say "    ${e}->${x} Sleeping for 30s and trying again..."
  sleep 30
done

say "    ${e}->${x} Uploading to Codecov"
i="0"
while [ $i -lt 4 ]
do
  i=$[$i+1]

  res=$(curl -X POST $curlargs $cacert --data-binary @$upload_file "$url/upload/v2?$query" -H 'Accept: text/plain' || echo 'HTTP 500')
  # HTTP 200
  # http://....
  status=$(echo "$res" | head -1 | cut -d' ' -f2)
  if [ "$status" = "" ];
  then
    say "    View reports at ${b}$(echo "$res" | head -2 | tail -1)${x}"
    exit 0

  elif [ "${status:0:1}" = "5" ];
  then
    say "    ${e}->${x} Sleeping for 30s and trying again..."
    sleep 30

  else
    say "    ${g}${res}${x}"
    exit 0
    exit ${exit_with}
  fi

done

fi

say "    ${r}X> Failed to upload coverage reports${x}"
exit ${exit_with}
