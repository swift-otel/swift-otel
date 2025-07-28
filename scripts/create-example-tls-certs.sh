#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift OTel open source project
##
## Copyright (c) 2025 the Swift OTel project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

mkdir -p certs

# Create CA private key
openssl genrsa -out certs/ca.key 4096

# Create CA certificate
openssl req -new -x509 -key certs/ca.key -sha256 -subj "/C=US/ST=CA/L=Cupertino/O=TestCA/CN=Test CA" -days 365 -out certs/ca.crt

# Create server private key
openssl genrsa -out certs/server.key 4096

# Create server certificate signing request
openssl req -new -key certs/server.key -out certs/server.csr -subj "/C=US/ST=CA/L=Cupertino/O=TestServer/CN=localhost"

# Create server certificate signed by CA
openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/server.crt -days 365 -sha256 \
  -extensions v3_req -extfile <(echo "[v3_req]"; echo "subjectAltName=DNS:localhost,IP:127.0.0.1")

# Create client private key
openssl genrsa -out certs/client.key 4096

# Create client certificate signing request
openssl req -new -key certs/client.key -out certs/client.csr -subj "/C=US/ST=CA/L=Cupertino/O=TestClient/CN=otel-client"

# Create client certificate signed by CA
openssl x509 -req -in certs/client.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/client.crt -days 365 -sha256

# Cleanup CSR files
rm certs/*.csr

echo "mTLS certificates generated successfully!"
echo "Files created:"
echo "  - certs/ca.crt (Certificate Authority)"
echo "  - certs/server.crt & server.key (Server certificate)"
echo "  - certs/client.crt & client.key (Client certificate)"
