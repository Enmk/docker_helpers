#! /bin/bash

# see into docker image: history, metadata, fs contents layer by layer, useful for comparing images
# usage:
#   docker_image_layers.sh <DOCKER_IMAGE_NAME> [<OUTPUT_DIRECTORY> [--unpack-layers]]
# where:
#   <DOCKER_IMAGE_NAME> is a fully qualified docker image name
#   <OUTPUT_DIRECTORY> directory to place unpacked docker image (for further manual examination perhaps?),
#       if not set image is upacked into temporary directory which is cleaned up later.
#   --unpack-layers if present, then docker image layers are going to be un-tared one-by-one into the <OUTPUT_DIRECTORY>.
#
# Dependencies: docker, tar, jq, sed

# Author: Vasily Nemkov / 2023
# License: MIT

readonly IMAGE_NAME="${1}"
OUTPUT_DIR="${2}"
UNPACK_LAYERS="${3}"

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

if [ "${UNPACK_LAYERS}" == '--unpack_layers' ]
then
    UNPACK_LAYERS=1
elif [ -n "${UNPACK_LAYERS}" ]
then
    echo "unknown argument '${UNPACK_LAYERS}'"
    exit -1
fi

echo ${IMAGE_NAME}

## pull image to local machine if it is not there yet
if ! docker inspect ${IMAGE_NAME} &>/dev/null ;
then
    echo Image ${IMAGE_NAME} not found, pulling it:
    docker pull ${IMAGE_NAME}
fi

# readonly OUTPUT_DIR="${OUTPUT_DIR}/${IMAGE_NAME//[\:\/]/_}"
# mkdir -p "${OUTPUT_DIR}"
readonly IMAGE_FILE_PATH="${OUTPUT_DIR}/layers.tar"

>&2 echo saving image ${IMAGE_NAME} as ${IMAGE_FILE_PATH}
docker save -o ${IMAGE_FILE_PATH} ${IMAGE_NAME} # dumps container contents to foobar.tar

readonly MANIFEST="$(tar -f ${IMAGE_FILE_PATH} -xO "manifest.json")"
readarray -t LAYERS_FILES <<< $(echo ${MANIFEST} | jq '.[0].Layers | .[]' -r)

readonly CONFIG_FILE_NAME="$(echo ${MANIFEST} | jq '.[0].Config' -r )"
# 'jq -c' to put every history object one line, and then as item in LAYERS_HISTORY
readarray -t LAYERS_HISTORY <<< $(tar -f ${IMAGE_FILE_PATH} -xO "${CONFIG_FILE_NAME}"  | jq '.history | .[] ' -c)


readonly SEP="=========================================================================="
# print metadata and contents of each layer
# since contents is intended for some sort of diff-ing, omit file timestamps
for i in "${!LAYERS_FILES[@]}"; do
    # e.g. 2aa1710669f95f12329428eff35ccba504d20e0300a140919ab8a4e09eef7553/layer.tar
    layer="${LAYERS_FILES[$i]}"
    history="${LAYERS_HISTORY[$i]}"

    echo $SEP
    echo "LAYER #$i ${layer/\/layer.tar/}"

    echo $SEP
    echo HISTORY
    echo ${history} | jq 'to_entries | .[] | map(.) | [join(":\t\"")] | join("\"\n")' -r

    echo $SEP
    echo METADATA
    # metadata is a separate file: e.g. 2aa1710669f95f12329428eff35ccba504d20e0300a140919ab8a4e09eef7553/json
    tar -f ${IMAGE_FILE_PATH} -xO ${layer/layer.tar/json} | jq '.'

    echo $SEP
    echo CONTENTS
    # sed is to remove timestamp and prepend leading '/' to file name
    tar -f ${IMAGE_FILE_PATH} -xO ${layer} | tar -tmv | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} /\//'
    echo

    if [ "$UNPACK_LAYERS" ]
    then
        LAYER_DIR_PATH="${OUTPUT_DIR}/layers/${i}"
        echo "layer output dir: ${LAYER_DIR_PATH}"
        mkdir -p "${OUTPUT_DIR}/layers/${i}"

        # Ignore errors that pop up sometimes (e.g. for ubuntu:20.04) and break processing: `tar: dev/audio: Cannot mknod: Operation not permitted`
        #(shopt +o pipefail; tar -f ${IMAGE_FILE_PATH} -xO ${layer} | tar -C "${LAYER_DIR_PATH}" -x) || true
        tar -f ${IMAGE_FILE_PATH} -xO ${layer} | tar -C "${LAYER_DIR_PATH}" -x 2>/dev/null ||:
    fi
#    exit -1
done
