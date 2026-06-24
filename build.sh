#!/usr/bin/env bash
set -euo pipefail

OMEGAT_DIR="${OMEGAT_DIR:-${1:-}}"

if [ -z "$OMEGAT_DIR" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 --omegat-dir /path/to/OmegaT"
    echo "   or: OMEGAT_DIR=/path/to/OmegaT $0"
    echo ""
    echo "Common paths:"
    echo "  Linux (manual):  ~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE"
    echo "  Linux (Flatpak): /var/lib/flatpak/app/org.omegat.OmegaT/current/active/files/omegat"
    echo "  macOS:           /Applications/OmegaT.app/Contents/Resources/Java"
    exit 1
fi

command -v javac >/dev/null 2>&1 || { echo "Error: javac not found (install JDK 11+)"; exit 1; }
command -v jar >/dev/null 2>&1   || { echo "Error: jar not found (install JDK 11+)"; exit 1; }

[ -d "$OMEGAT_DIR" ]            || { echo "Error: directory not found: $OMEGAT_DIR"; exit 1; }
[ -f "$OMEGAT_DIR/OmegaT.jar" ] || { echo "Error: OmegaT.jar not found in $OMEGAT_DIR"; exit 1; }
[ -d "$OMEGAT_DIR/lib" ]        || { echo "Error: lib/ directory not found in $OMEGAT_DIR"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patch/org/omegat/core/machinetranslators/DeepLTranslate.java"
[ -f "$PATCH_FILE" ] || { echo "Error: patch source not found: $PATCH_FILE"; exit 1; }

if command -v lsof >/dev/null 2>&1 && lsof "$OMEGAT_DIR/OmegaT.jar" >/dev/null 2>&1; then
    echo "Error: OmegaT is running. Close it before patching."
    exit 1
fi

BACKUP="$OMEGAT_DIR/OmegaT.jar.bak.$(date +%Y%m%d%H%M%S)"
cp "$OMEGAT_DIR/OmegaT.jar" "$BACKUP"
echo "[*] Backup created: $BACKUP"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

CLASSPATH="$OMEGAT_DIR/OmegaT.jar"
for jar in "$OMEGAT_DIR"/lib/*.jar; do
    CLASSPATH="$CLASSPATH:$jar"
done

cp -r "$SCRIPT_DIR/patch"/* "$TMPDIR/"
javac -cp "$CLASSPATH" "$TMPDIR"/org/omegat/core/machinetranslators/DeepLTranslate.java

CLASS_FILE="$TMPDIR/org/omegat/core/machinetranslators/DeepLTranslate.class"
[ -f "$CLASS_FILE" ] || { echo "Error: compilation failed (no .class produced)"; exit 1; }

jar uf "$OMEGAT_DIR/OmegaT.jar" -C "$TMPDIR" org/omegat/core/machinetranslators/DeepLTranslate.class

jar tf "$OMEGAT_DIR/OmegaT.jar" | grep -q "DeepLTranslate.class" \
    || { echo "Error: patch verification failed"; exit 1; }

echo "[+] Done! DeepLTranslate patched successfully."
