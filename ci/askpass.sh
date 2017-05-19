#!/bin/sh
set +x # No secret printing!
exec printf "${OCEAN_D2_PASS}"
