#!/usr/bin/env bash
#
# Download the latest Linux asbmutil release and load API credentials from the
# environment, so a headless CI job (GitHub Actions, Azure DevOps, GitLab, …)
# can talk to Apple Business/School Manager with no Mac and no Keychain.
#
# The static Linux binary reads credentials from ~/.config/asbmutil/ (a file
# store, since there's no Keychain on Linux). `asbmutil config set` writes that
# store for us, so all this script needs from the environment is:
#
#   ASBM_CLIENT_ID        e.g. BUSINESSAPI.84c7b9e1-...
#   ASBM_KEY_ID           the API key id
#   ASBM_PRIVATE_KEY_PEM  the PEM private key, contents (not a path)
#
# After sourcing/running this, `asbmutil` is on PATH via ./bin and ready to use.
#
# Usage:
#   ASBM_CLIENT_ID=... ASBM_KEY_ID=... ASBM_PRIVATE_KEY_PEM="$(cat key.pem)" \
#     ./setup-asbmutil.sh
set -euo pipefail

REPO="rodchristiansen/asbmutil"
BIN_DIR="${BIN_DIR:-$PWD/bin}"

# 1. Fetch the latest Linux release asset and unpack it.
mkdir -p "$BIN_DIR"
asset_url=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | python3 -c "import sys,json; a=json.load(sys.stdin)['assets']; print(next(x['browser_download_url'] for x in a if 'linux' in x['name']))")
echo "Downloading asbmutil: $asset_url"
curl -fsSL -o /tmp/asbmutil.tar.gz "$asset_url"
tar xzf /tmp/asbmutil.tar.gz -C "$BIN_DIR"
chmod +x "$BIN_DIR/asbmutil"
rm -f /tmp/asbmutil.tar.gz
export PATH="$BIN_DIR:$PATH"

# 2. Load credentials into the file store via `config set`.
: "${ASBM_CLIENT_ID:?set ASBM_CLIENT_ID}"
: "${ASBM_KEY_ID:?set ASBM_KEY_ID}"
: "${ASBM_PRIVATE_KEY_PEM:?set ASBM_PRIVATE_KEY_PEM}"

pem_file=$(mktemp)
trap 'rm -f "$pem_file"' EXIT
printf '%s' "$ASBM_PRIVATE_KEY_PEM" > "$pem_file"

asbmutil config set \
  --client-id "$ASBM_CLIENT_ID" \
  --key-id "$ASBM_KEY_ID" \
  --pem-path "$pem_file"

echo "asbmutil ready: $(asbmutil --version 2>/dev/null || echo installed)"
