#!/bin/bash
set -euo pipefail
keychain="$HOME/Library/Keychains/build.keychain-db"
security create-keychain -p "" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "" "$keychain"
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
# Use the existing documented certificate password only for the tracked certificate.
password="${P12_PASSWORD:-likeart}"
openssl pkcs12 -in build-b2/distribution.p12 -passin "pass:$password" -clcerts -nokeys -out build-b2/cert.pem
openssl pkcs12 -in build-b2/distribution.p12 -passin "pass:$password" -nocerts -nodes -out build-b2/key.pem
security import build-b2/cert.pem -k "$keychain" -T /usr/bin/codesign
security import build-b2/key.pem -k "$keychain" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "" "$HOME/Library/Keychains/build.keychain-db"
security find-identity -v -p codesigning "$keychain" | tee build-b2/evidence/signing-identities.txt
rm build-b2/key.pem build-b2/cert.pem build-b2/distribution.p12
