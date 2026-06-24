#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--omegat-dir" ] && [ -n "${2:-}" ]; then
    OMEGAT_DIR="$2"
else
    OMEGAT_DIR="${OMEGAT_DIR:-${1:-}}"
fi

if [ -z "$OMEGAT_DIR" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 --omegat-dir /path/to/OmegaT"
    echo "   or: OMEGAT_DIR=/path/to/OmegaT $0"
    exit 1
fi

if [ ! -f "$OMEGAT_DIR/OmegaT.jar" ]; then
    echo "FAIL: OmegaT.jar not found at $OMEGAT_DIR/OmegaT.jar"
    exit 1
fi

echo "[*] Checking OmegaT.jar for patched DeepLTranslate class..."

if jar tf "$OMEGAT_DIR/OmegaT.jar" | grep -q "DeepLTranslate.class"; then
    echo "  - DeepLTranslate.class: present"
else
    echo "FAIL: DeepLTranslate.class missing from OmegaT.jar"
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
jar xf "$OMEGAT_DIR/OmegaT.jar" org/omegat/core/machinetranslators/DeepLTranslate.class

CLASS_FILE="org/omegat/core/machinetranslators/DeepLTranslate.class"

# Check for v2 endpoint string in the class
if strings "$CLASS_FILE" | grep -q "api-free.deepl.com"; then
    echo "  - API host: api-free.deepl.com (patched, default)"
elif strings "$CLASS_FILE" | grep -q "api.deepl.com/v1"; then
    echo "  - API: ORIGINAL v1 endpoint (not patched)"
    exit 1
else
    echo "  - API host: custom (set via DEEPL_API_HOST)"
fi

# Check for Authorization header
if strings "$CLASS_FILE" | grep -q "DeepL-Auth-Key"; then
    echo "  - Auth method: Authorization header (patched)"
else
    echo "  - Auth method: ORIGINAL (not patched)"
    exit 1
fi

# Check for User-Agent
if strings "$CLASS_FILE" | grep -q "Mozilla/5.0"; then
    echo "  - User-Agent: browser-style (patched)"
else
    echo "  - User-Agent: ORIGINAL (not patched)"
    exit 1
fi

echo ""
echo "PASS: OmegaT.jar is patched with the DeepL v2 fix."

echo ""
echo "To test the translation API directly:"
echo "  curl -s -X POST \"https://api-free.deepl.com/v2/translate\" \\"
echo "    -H \"Authorization: DeepL-Auth-Key \\\$DEEPL_API_KEY\" \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"text\":[\"Hello world\"],\"target_lang\":\"ES\"}'"
