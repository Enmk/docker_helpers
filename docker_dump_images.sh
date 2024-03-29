#!/bin/bash

# dump docker image structure and list of installed packages,
# making it easier to compare images of different versions
# with visual comparison tools like diff, meld, kdiff3, etc.
#
# Dependencies: docker_image_installed_packages.sh, docker_image_layers.sh
# Usage:
# docker_dump_images.sh TMP_OUTPUT ubuntu:20.04 ubuntu:22.04

# Author: Vasily Nemkov / 2023
# License: MIT

set -ex

OUTPUT_DIR="$(realpath $1)"
shift 1

for image in "$@";
do
    # strip tag name (basically everything with and after ':' ) for easy comparison of different image versions with diff
    # for some reason "${image//:+(*)/}" nor "${image//:+([a-zA-Z0-9\._-])/}" doesn't work here
    image_as_filename="${image/:/\/}" #"$(export IFS=: && for i in ${image}; do echo $i && exit 0; done)"
    IMAGE_OUTPUT_DIR="${OUTPUT_DIR}/${image_as_filename}"
    echo "image '${image}' goes to '$IMAGE_OUTPUT_DIR'" >&2

    mkdir -p ${IMAGE_OUTPUT_DIR}
    docker_image_layers.sh \
        ${image} \
        ${IMAGE_OUTPUT_DIR} \
        ${DOCKER_IMAGE_LAYERS_EXTRA_ARGS} \
        > "${IMAGE_OUTPUT_DIR}/layers.txt" ||:

    docker_image_installed_packages.sh ${image}> ${IMAGE_OUTPUT_DIR}/installed.txt ||:
done
