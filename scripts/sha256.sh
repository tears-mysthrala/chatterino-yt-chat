#!/usr/bin/env bash
set -euo pipefail

FILE="${1:?zip file required}"
sha256sum "$FILE" > "${FILE}.sha256"
cat "${FILE}.sha256"
