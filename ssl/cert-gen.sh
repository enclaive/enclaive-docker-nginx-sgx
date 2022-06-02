#! /bin/bash

if [ ! -f server.crt ]
then
    echo "'server.crt' does not exist. Generating a self-signed server cert from 'ca.conf'"
    echo "Do NOT use self-signed certificates in production environments."
	openssl genrsa -out ca.key 2048
	openssl req -x509 -new -nodes -key ca.key -sha256 -days 1024 -out ca.crt -config ca.conf
	openssl genrsa -out server.key 2048
	openssl req -new -key server.key -out server.csr -config ca.conf
	openssl x509 -req -days 360 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt
	
else
    echo "'server.crt' found. Parsing the certificate..."
fi

