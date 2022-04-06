#!/bin/sh
set -e



cd /app

gramine-sgx-get-token --output php.token --sig php.sig
gramine-sgx php --force-stderr --nodaemonize &

gramine-sgx-get-token --output nginx.token --sig nginx.sig
gramine-sgx nginx
