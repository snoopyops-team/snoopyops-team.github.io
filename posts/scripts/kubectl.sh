#!/bin/bash
cd /usr/local/src
wget "https://storage.googleapis.com/kubernetes-release/release/v1.19.16/kubernetes-client-linux-amd64.tar.gz"
tar xf kubernetes-client-linux-amd64.tar.gz
mv /usr/local/src/kubernetes/client/bin/kubectl /usr/local/bin/

