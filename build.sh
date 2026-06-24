#!/usr/bin/env bash
set -euo pipefail

OMEGAT_DIR="${OMEGAT_DIR:-${1:-}}"

if [ -z "$OMEGAT_DIR" ]; then
    echo "Usage: $0 --omegat-dir /path/to/OmegaT"
    echo "   or: OMEGAT_DIR=/path/to/OmegaT $0"
    exit 1
fi

if [ ! -f "$OMEGAT_DIR/OmegaT.jar" ]; then
    echo "Error: OmegaT.jar not found in $OMEGAT_DIR"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/patch"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "[*] Compiling DeepLTranslate.java..."
CLASSPATH="$OMEGAT_DIR/OmegaT.jar"
for jar in "$OMEGAT_DIR"/lib/*.jar; do
    CLASSPATH="$CLASSPATH:$jar"
done

cp -r "$PATCH_DIR"/* "$TMPDIR/"
javac -cp "$CLASSPATH" "$TMPDIR"/org/omegat/core/machinetranslators/DeepLTranslate.java

echo "[*] Patching OmegaT.jar..."
jar uf "$OMEGAT_DIR/OmegaT.jar" -C "$TMPDIR" org/omegat/core/machinetranslators/DeepLTranslate.class

echo "[+] Done! DeepLTranslate patched successfully."
