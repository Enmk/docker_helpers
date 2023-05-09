#! /bin/bash

# see into docker image: history, metadata, fs contents layer by layer, useful for comparing images
# usage:
#   docker_image_layers.sh <DOCKER_IMAGE_NAME> [<OUTPUT_DIRECTORY>]
# where:
#   <DOCKER_IMAGE_NAME> is a fully qualified docker image name
#   <OUTPUT_DIRECTORY> directory to place unpacked docker image (for further manual examination perhaps?),
#       if not set image is upacked into temporary directory which is cleaned up later.
#
# Dependencies: docker, tar, jq, sed

# Author: Vasily Nemkov / 2023
# License: MIT

readonly IMAGE_NAME="${1}"
OUTPUT_DIR="${2}"

set -eu pipefail

if [ ${OUTPUT_DIR} ] ;
then
    echo using "${OUTPUT_DIR}" as storage for ${IMAGE_NAME} layers
    mkdir -p "${OUTPUT_DIR}"
else
    readonly TMP_DIR="$(mktemp -d -t)"
    trap 'rm -rf -- "$TMP_DIR"' EXIT
    echo ${TMP_DIR}
    OUTPUT_DIR="${TMP_DIR}"
    echo ${OUTPUT_DIR}
fi

echo ${IMAGE_NAME}

## pull image to local machine if it is not there yet
if ! docker inspect ${IMAGE_NAME} &>/dev/null ;
then
    echo Image ${IMAGE_NAME} not found, pulling it:
    docker pull ${IMAGE_NAME}
fi

readonly IMAGE_FILE_NAME="${OUTPUT_DIR}/${IMAGE_NAME//[\:\/]/_}.layers.tar"
>&2 echo saving image ${IMAGE_NAME} as ${IMAGE_FILE_NAME}
docker save -o ${IMAGE_FILE_NAME} ${IMAGE_NAME} # dumps container contents to foobar.tar

readonly MANIFEST="$(tar -f ${IMAGE_FILE_NAME} -xO "manifest.json")"
readarray -t LAYERS_FILES <<< $(echo ${MANIFEST} | jq '.[0].Layers | .[]' -r)

readonly CONFIG_FILE_NAME="$(echo ${MANIFEST} | jq '.[0].Config' -r )"
# 'jq -c' to put every history object one line, and then as item in LAYERS_HISTORY
readarray -t LAYERS_HISTORY <<< $(tar -f ${IMAGE_FILE_NAME} -xO "${CONFIG_FILE_NAME}"  | jq '.history | .[] ' -c)


readonly SEP="=========================================================================="
# print metadata and contents of each layer
# since contents is intended for some sort of diff-ing, omit file timestamps
for i in "${!LAYERS_FILES[@]}"; do
    layer="${LAYERS_FILES[$i]}"
    history="${LAYERS_HISTORY[$i]}"

    echo $SEP
    echo "LAYER #$i ${layer/\/layer.tar/}"

    echo $SEP
    echo HISTORY
    echo ${history} | jq 'to_entries | .[] | map(.) | [join(":\t\"")] | join("\"\n")' -r

    echo $SEP
    echo METADATA
    tar -f ${IMAGE_FILE_NAME} -xO ${layer/layer.tar/json} | jq '.'

    echo $SEP
    echo CONTENTS
    # sed is to remove timestamp and prepend leading '/' to file name
    tar -f ${IMAGE_FILE_NAME} -xO ${layer} | tar -tmv | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} /\//'
    echo
done
