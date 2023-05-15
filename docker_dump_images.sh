#!/bin/bash

# dump docker image structure and list of installed packages,
# making it easier to compare images of different versions
# with visual comparison tools like diff, meld, kdiff3, etc.
#
# Dependencies: docker_image_installed_packages.sh, docker_image_layers.sh

# Author: Vasily Nemkov / 2023
# License: MIT

set -e

OUTPUT_DIR="$(realpath $1)"
shift 1

for image in "$@";
do
    echo image ${image} >&2

    # strip tag name (basically everything with and after ':' ) for easy comparison of different image versions with diff
    # for some reason "${image//:+(*)/}" nor "${image//:+([a-zA-Z0-9\._-])/}" doesn't work here
    image_as_filename="$(export IFS=: && for i in ${image}; do echo $i && exit 0; done)"
    IMAGE_OUTPUT_DIR="${OUTPUT_DIR}/${image_as_filename}"
    echo 'Will write stuff to: ' $IMAGE_OUTPUT_DIR >&2

    mkdir -p ${IMAGE_OUTPUT_DIR}
    docker_image_layers.sh \
        ${image} \
        ${IMAGE_OUTPUT_DIR} \
        > "${IMAGE_OUTPUT_DIR}/layers.txt"

    docker_image_installed_packages.sh ${image}> ${IMAGE_OUTPUT_DIR}/installed.txt

    echo
done
