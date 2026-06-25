#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf '%b→%b %s\n' "$GREEN" "$NC" "$*"; }
die()  { printf '%b→%b %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *) die "Only macOS and Linux are supported." ;;
esac

detect_omegat_dir() {
    [ -n "${OMEGAT_DIR:-}" ] && return 0
    candidates=()
    if [ "$OS" = "macos" ]; then
        [ -d "/Applications/OmegaT.app/Contents/Java" ] && candidates+=("/Applications/OmegaT.app/Contents/Java")
    else
        for path in "$HOME/.local/opt/omegat"/OmegaT_* "$HOME/omegat"/OmegaT_* "/opt/omegat"/OmegaT_*; do
            [ -d "$path" ] && candidates+=("$path")
        done
        flatpak_dir="/var/lib/flatpak/app/org.omegat.OmegaT/current/active/files/omegat"
        [ -d "$flatpak_dir" ] && candidates+=("$flatpak_dir")
    fi
    for path in "${candidates[@]}"; do
        [ -f "$path/OmegaT.jar" ] && [ -d "$path/lib" ] && { OMEGAT_DIR="$path"; return 0; }
    done
    die "OmegaT not found. Open OmegaT once and run again."
}

if [ "${1:-}" = "--omegat-dir" ] && [ -n "${2:-}" ]; then
    OMEGAT_DIR="$2"
    shift 2
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            echo "Usage: $0 [--omegat-dir PATH]"
            echo "Auto-detects OmegaT if no path is given."
            exit 0
            ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

detect_omegat_dir
[ -f "$OMEGAT_DIR/OmegaT.jar" ] || die "OmegaT.jar not found"

ok "Checking..."
jar tf "$OMEGAT_DIR/OmegaT.jar" | grep -q "DeepLTranslate.class" || die "DeepL component missing from OmegaT"

CLASS_DUMP=$(javap -classpath "$OMEGAT_DIR/OmegaT.jar" -verbose org.omegat.core.machinetranslators.DeepLTranslate)

if printf '%s\n' "$CLASS_DUMP" | grep -q "api-free.deepl.com"; then
    printf '  → API: v2 endpoint (fixed)\n'
elif printf '%s\n' "$CLASS_DUMP" | grep -q "api.deepl.com/v1"; then
    die "API: v1 endpoint still present (not fixed)"
else
    printf '  → API: custom host\n'
fi

if printf '%s\n' "$CLASS_DUMP" | grep -q "DeepL-Auth-Key"; then
    printf '  → Auth: header (fixed)\n'
else
    die "Auth: header missing (not fixed)"
fi

if printf '%s\n' "$CLASS_DUMP" | grep -q "Mozilla/5.0"; then
    printf '  → Agent: browser-style (fixed)\n'
else
    die "Agent: browser-style missing (not fixed)"
fi

echo ""
ok "OmegaT is ready."
