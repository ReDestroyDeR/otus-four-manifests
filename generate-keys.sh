#!/bin/bash
mkdir .temp
openssl genpkey -algorithm RSA -out .temp/private.pem -pkeyopt rsa_keygen_bits:2048
openssl rsa -pubout -in .temp/private.pem -out .temp/public_key.pem

rm keys.env
echo "JWT_PRIVATE_KEY=$(cat .temp/private.pem | base64 | tr --delete '\n')" >> keys.env
echo "JWT_PUBLIC_KEY=$(cat .temp/public_key.pem | base64 | tr --delete '\n')" >> keys.env
rm -rf .temp

