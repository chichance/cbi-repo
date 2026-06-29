#!/bin/bash

# Ensure a file was provided
if [ -z "$1" ]; then
    echo "Usage: ./cbi-sign.sh <path_to_file> [version]"
    exit 1
fi

FILE="$1"
VERSION="${2:-1.0.0}" # Defaults to 1.0.0 if not specified
FILENAME=$(basename "$FILE")

# Configuration paths
REPO_DIR="$HOME/cbi-repo"
KEY="$REPO_DIR/keys/cbi-signing.key"
PUB_KEY="$REPO_DIR/keys/cbi-signing.pub"
SIG_DIR="$REPO_DIR/signatures"
MANIFEST_DIR="$REPO_DIR/manifests"
DB="$REPO_DIR/repo.db"

# 1. Verify file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found."
    exit 1
fi

echo "=== Processing: $FILENAME ==="

# 2. Calculate SHA256 Hash
HASH=$(sha256sum "$FILE" | awk '{print $1}')
echo "[+] SHA256 Hash: $HASH"

# 3. Generate Cryptographic Signature
SIG_FILE="$SIG_DIR/${FILENAME}.sig"
openssl dgst -sha256 -sign "$KEY" -out "$SIG_FILE" "$FILE"
echo "[+] Signature created: signatures/${FILENAME}.sig"

# 4. Generate JSON Manifest
MANIFEST_FILE="$MANIFEST_DIR/${FILENAME}.json"
cat > "$MANIFEST_FILE" << EOM
{
  "name": "$FILENAME",
  "version": "$VERSION",
  "sha256": "$HASH",
  "signature": "signatures/${FILENAME}.sig",
  "author": "CBI"
}
EOM
echo "[+] Manifest created: manifests/${FILENAME}.json"

# 5. Log into SQLite Trust Database
sqlite3 "$DB" << EOM
INSERT OR REPLACE INTO artifacts (name, version, sha256, signature)
VALUES ('$FILENAME', '$VERSION', '$HASH', 'signatures/${FILENAME}.sig');
EOM
echo "[+] Database ledger updated."
echo "=== Success ==="
