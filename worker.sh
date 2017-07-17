#!/usr/bin/env bash
set -e -x

# use this to start up remote workers as you see fit, remember you have to do the key exchange

docker run --rm \
    --name worker \
    -e CONCOURSE_GARDEN_DNS_SERVER=8.8.8.8 \
    -e CONCOURSE_TSA_HOST=192.168.254.50 \
    -v $PWD/permkeys/worker:/concourse-keys \
    --privileged \
    concourse/concourse:3.2.1 \
    worker
