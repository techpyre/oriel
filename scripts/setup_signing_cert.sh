#!/usr/bin/env bash
set -euo pipefail

CERT_NAME="${ORIEL_SIGN_IDENTITY:-Oriel Local Signing}"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

if security find-certificate -c "${CERT_NAME}" "${KEYCHAIN}" >/dev/null 2>&1; then
    echo "==> Code signing identity '${CERT_NAME}' already exists in login keychain."
    exit 0
fi

echo "==> Creating persistent local code signing identity '${CERT_NAME}'..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

cat > "${TMP_DIR}/cert.cnf" <<EOF
[ req ]
default_bits       = 2048
distinguished_name = dn
x509_extensions    = v3_code_sign
prompt             = no

[ dn ]
CN = ${CERT_NAME}

[ v3_code_sign ]
basicConstraints = critical,CA:FALSE
keyUsage         = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF

# Prefer Apple's built-in /usr/bin/openssl (LibreSSL) for macOS Keychain PKCS#12 compatibility
OPENSSL_BIN="/usr/bin/openssl"
if [[ ! -x "${OPENSSL_BIN}" ]]; then
    OPENSSL_BIN="$(command -v openssl)"
fi

"${OPENSSL_BIN}" req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "${TMP_DIR}/key.pem" \
    -out "${TMP_DIR}/cert.pem" \
    -config "${TMP_DIR}/cert.cnf" 2>/dev/null

# Export PKCS#12 compatible with macOS security import
if "${OPENSSL_BIN}" pkcs12 -export -legacy \
    -in "${TMP_DIR}/cert.pem" -inkey "${TMP_DIR}/key.pem" \
    -out "${TMP_DIR}/cert.p12" -passout pass:oriel 2>/dev/null; then
    true
else
    "${OPENSSL_BIN}" pkcs12 -export \
        -in "${TMP_DIR}/cert.pem" -inkey "${TMP_DIR}/key.pem" \
        -out "${TMP_DIR}/cert.p12" -passout pass:oriel 2>/dev/null
fi

security import "${TMP_DIR}/cert.p12" \
    -k "${KEYCHAIN}" \
    -P oriel \
    -T /usr/bin/codesign \
    -T /usr/bin/security >/dev/null

echo "==> Installed '${CERT_NAME}' into ${KEYCHAIN}."
