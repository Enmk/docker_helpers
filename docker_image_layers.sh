#! /bin/bash

# ls into docker image layer by layer, useful for comparing images

set -e

readonly IMAGE_NAME="$1"
readonly TMP_DIR=$(mktemp -d -t)
trap 'rm -rf -- "$TMP_DIR"' EXIT

echo ${IMAGE_NAME}

# IMAGE_FILE_NAME=/home/enmk/work/altinity/clickhouse_binary-builder_40356-86b0ecd5d513d6f32ad01b7046ab761d4f2f177c.layers.tar
readonly IMAGE_FILE_NAME="${TMP_DIR}/${IMAGE_NAME//[\:\/]/_}.layers.tar"
>&2 echo saving image ${IMAGE_NAME} as ${IMAGE_FILE_NAME}
docker save -o ${IMAGE_FILE_NAME} ${IMAGE_NAME} # dumps container contents to foobar.tar

readarray -t LAYERS_FILES <<< $(tar -f ${IMAGE_FILE_NAME} -xO "manifest.json" | jq '.[0].Layers | .[]' | tr -d '"')
readonly SEP="=========================================================================="

# print metadata and contents of each layer
# since contents is intended for some sort of diff-ing, omit file timestamps
for i in "${!LAYERS_FILES[@]}"; do 
    layer="${LAYERS_FILES[$i]}"

    echo $SEP
    echo "Layer #$i ${layer/\/layer.tar/}"

    echo $SEP
    echo metadata:
    json="${layer/layer.tar/json}"
    tar -f ${IMAGE_FILE_NAME} -xO ${json} | jq '.'

    echo $SEP
    echo contents:
    # sed is to remove timestamp
    tar -f ${IMAGE_FILE_NAME} -xO ${layer} | tar -tmv | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} //'
    echo
done
