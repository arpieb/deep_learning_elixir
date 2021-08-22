#!/bin/bash
docker run -it --gpus all --network host -v $(pwd)/notebooks:/notebooks dle:latest
