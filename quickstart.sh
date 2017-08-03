#!/usr/bin/env bash
wget -O /tmp/fly https://github.com/concourse/concourse/releases/download/v3.2.1/fly_linux_amd64
mv /tmp/fly /usr/local/bin/fly
chmod +x /usr/local/bin/fly
which fly

mkdir -p keys/web keys/worker

ssh-keygen -t rsa -f ./keys/web/tsa_host_key -N ''
ssh-keygen -t rsa -f ./keys/web/session_signing_key -N ''

ssh-keygen -t rsa -f ./keys/worker/worker_key -N ''

cp ./keys/worker/worker_key.pub ./keys/web/authorized_worker_keys
cp ./keys/web/tsa_host_key.pub ./keys/worker

docker-compose up -d