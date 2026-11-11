#!/usr/bin/env bash
# Self-signed certificate for the optional HTTPS proxy. Usage: scripts/make-cert.sh gofr.example.org
# Import certs/gofr.crt into the OpenELIS truststore (see the Integration Overview page).
set -euo pipefail
cd "$(dirname "$0")/.."
host="${1:?usage: scripts/make-cert.sh <host name>}"
openssl req -x509 -newkey rsa:2048 -nodes -days 825 -subj "/CN=${host}" \
  -addext "subjectAltName=DNS:${host},DNS:localhost" -keyout certs/gofr.key -out certs/gofr.crt
echo "Wrote certs/gofr.crt and certs/gofr.key for ${host}"
