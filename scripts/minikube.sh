#!/usr/bin/bash

# make Docker commands work with remote Minikube that has TLS enabled but incorrect certificate
alias docker='docker --tls'  

export DOCKER_HOST="tcp://mini:61278"
export DOCKER_CERT_PATH="$HOME/.minikube/certs"
