#!/bin/bash

# see into docker image: ask system package managers for list of installed packages
# usage:
#   docker_image_installed_packages.sh <DOCKER_IMAGE_NAME>
# where:
#   <DOCKER_IMAGE_NAME> is a fully qualified docker image name
#
# Supports:
#   apk, apt, yum -- as system package managers are supported
#   pip, pip3 -- as python package managers
# Currently missing support of listing packagers for:
#   perl, npm, (insert your package manager name here)
#
# Dependencies: docker, sh (must be present in docker image)

# Author: Vasily Nemkov / 2023
# License: MIT


docker run -it --entrypoint sh $1 -c '
set -e;
one_of() {
    args="$@"
    for p in $args; do
        $p --help 1>/dev/null 2>/dev/null && echo $p && return 0
    done
    # nothing found
    printf "not found: $args" 1>&2
    printf "false && " exit -1
}

## Piping through cat forces monochromic output
$(one_of apt apk yum) list --installed | cat

$(one_of pip pip3) list | cat'