#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=""
POSITIONAL=()
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN="1"; shift ;;
        --omegat-dir) OMEGAT_DIR="$2"; shift 2 ;;
        --help|-h) HELP="1"; shift ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done

if [ -z "${OMEGAT_DIR:-}" ] && [ ${#POSITIONAL[@]} -gt 0 ]; then
    OMEGAT_DIR="${POSITIONAL[0]}"
fi

if [ -z "${OMEGAT_DIR:-}" ] || [ -n "${HELP:-}" ]; then
    echo "Usage: $0 [--dry-run] --omegat-dir /path/to/OmegaT"
    echo "   or: $0 [--dry-run] /path/to/OmegaT"
    echo "   or: OMEGAT_DIR=/path/to/OmegaT $0 [--dry-run]"
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would be done without making changes"
    echo ""
    echo "Common paths:"
    echo "  Linux (manual):  ~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE"
    echo "  Linux (Flatpak): /var/lib/flatpak/app/org.omegat.OmegaT/current/active/files/omegat"
    echo "  macOS:           /Applications/OmegaT.app/Contents/Resources/Java"
    exit 1
fi

if [ -n "$DRY_RUN" ]; then
    echo "[*] DRY RUN — no changes will be made"
    echo ""
fi

echo "[CHECK] javac..."
command -v javac >/dev/null 2>&1 || { echo "  FAIL: javac not found (install JDK 11+)"; exit 1; }
echo "  FOUND: $(command -v javac)"

echo "[CHECK] jar..."
command -v jar >/dev/null 2>&1 || { echo "  FAIL: jar not found (install JDK 11+)"; exit 1; }
echo "  FOUND: $(command -v jar)"

echo "[CHECK] OmegaT directory..."
[ -d "$OMEGAT_DIR" ] || { echo "  FAIL: directory not found: $OMEGAT_DIR"; exit 1; }
echo "  OK: $OMEGAT_DIR"

echo "[CHECK] OmegaT.jar..."
[ -f "$OMEGAT_DIR/OmegaT.jar" ] || { echo "  FAIL: OmegaT.jar not found"; exit 1; }
echo "  OK: $OMEGAT_DIR/OmegaT.jar"

echo "[CHECK] lib/ directory..."
[ -d "$OMEGAT_DIR/lib" ] || { echo "  FAIL: lib/ not found"; exit 1; }
JAR_COUNT=$(ls -1 "$OMEGAT_DIR"/lib/*.jar 2>/dev/null | wc -l)
echo "  OK: $JAR_COUNT jars found"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patch/org/omegat/core/machinetranslators/DeepLTranslate.java"
echo "[CHECK] patch source..."
[ -f "$PATCH_FILE" ] || { echo "  FAIL: patch source not found: $PATCH_FILE"; exit 1; }
echo "  OK: $PATCH_FILE"

echo "[CHECK] OmegaT running..."
if command -v lsof >/dev/null 2>&1 && lsof "$OMEGAT_DIR/OmegaT.jar" >/dev/null 2>&1; then
    echo "  FAIL: OmegaT is running. Close it before patching."
    exit 1
fi
echo "  OK: not running"

CLASSPATH="$OMEGAT_DIR/OmegaT.jar"
for jar in "$OMEGAT_DIR"/lib/*.jar; do
    CLASSPATH="$CLASSPATH:$jar"
done

echo ""
echo "Plan:"
echo "  1. Backup:  $OMEGAT_DIR/OmegaT.jar -> OmegaT.jar.bak.<timestamp>"
echo "  2. Compile: javac -cp <classpath> $PATCH_FILE"
echo "  3. Patch:   jar uf $OMEGAT_DIR/OmegaT.jar .../DeepLTranslate.class"
echo "  4. Verify:  jar tf $OMEGAT_DIR/OmegaT.jar | grep DeepLTranslate.class"

if [ -n "$DRY_RUN" ]; then
    echo ""
    echo "[*] DRY RUN complete — no changes were made."
    exit 0
fi

BACKUP="$OMEGAT_DIR/OmegaT.jar.bak.$(date +%Y%m%d%H%M%S)"
cp "$OMEGAT_DIR/OmegaT.jar" "$BACKUP"
echo "[*] Backup created: $BACKUP"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$SCRIPT_DIR/patch"/* "$TMPDIR/"
javac -cp "$CLASSPATH" "$TMPDIR"/org/omegat/core/machinetranslators/DeepLTranslate.java

CLASS_FILE="$TMPDIR/org/omegat/core/machinetranslators/DeepLTranslate.class"
[ -f "$CLASS_FILE" ] || { echo "Error: compilation failed (no .class produced)"; exit 1; }

jar uf "$OMEGAT_DIR/OmegaT.jar" -C "$TMPDIR" org/omegat/core/machinetranslators/DeepLTranslate.class

jar tf "$OMEGAT_DIR/OmegaT.jar" | grep -q "DeepLTranslate.class" \
    || { echo "Error: patch verification failed"; exit 1; }

echo "[+] Done! DeepLTranslate patched successfully."
