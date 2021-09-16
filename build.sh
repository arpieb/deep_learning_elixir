#!/bin/bash
CONTAINER_NAME=dle
docker container rm ${CONTAINER_NAME}
docker build . --network=host -t ${CONTAINER_NAME}
docker create -it --gpus all --network host -v $(pwd)/notebooks:/notebooks --name ${CONTAINER_NAME} ${CONTAINER_NAME}:latest
