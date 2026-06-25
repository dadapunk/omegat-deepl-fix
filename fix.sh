#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf '%b→%b %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%b→%b %s\n' "$YELLOW" "$NC" "$*"; }
err()  { printf '%b→%b %s\n' "$RED" "$NC" "$*" >&2; }
die()  { err "$1"; exit 1; }

MODE="build"
DRY_RUN=""
CHOOSE=""
OMEGAT_DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --build|-b) MODE="build" ;;
        --check|-c) MODE="check" ;;
        --undo|-u) MODE="undo" ;;
        --dry-run) DRY_RUN="1" ;;
        --choose) CHOOSE="1" ;;
        --omegat-dir) OMEGAT_DIR="$2"; shift ;;
        --help|-h)
            cat <<EOF
Usage: fix.sh [mode] [options]

Modes:
  (default)    Patch OmegaT
  --check      Verify if OmegaT is patched
  --undo       Restore from backup

Options:
  --omegat-dir PATH  OmegaT location (auto-detected)
  --dry-run          Preview without changing anything
  --choose           Pick which backup to restore from
  -h, --help         Show this help
EOF
            exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *) die "Only macOS and Linux are supported." ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_CLASS="$SCRIPT_DIR/patch/org/omegat/core/machinetranslators/DeepLTranslate.class"

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
    return 1
}

confirm() {
    local q="$1" d="${2:-N}"
    [ ! -t 0 ] && return 1
    local s="[y/N]"; [ "$d" = "Y" ] && s="[Y/n]"
    printf '%s %s ' "$q" "$s"
    read -r a || true
    case "${a:-$d}" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

cmd_check() {
    detect_omegat_dir || die "OmegaT not found. Open OmegaT once and run again."
    [ -f "$OMEGAT_DIR/OmegaT.jar" ] || die "OmegaT.jar not found"

    ok "Checking..."

    unzip -l "$OMEGAT_DIR/OmegaT.jar" 2>/dev/null | grep "DeepLTranslate.class" >/dev/null || die "DeepL component missing from OmegaT"

    local issue=0

    if unzip -p "$OMEGAT_DIR/OmegaT.jar" org/omegat/core/machinetranslators/DeepLTranslate.class 2>/dev/null | grep -a "api-free.deepl.com" >/dev/null; then
        printf '  → API: v2 endpoint (fixed)\n'
    elif unzip -p "$OMEGAT_DIR/OmegaT.jar" org/omegat/core/machinetranslators/DeepLTranslate.class 2>/dev/null | grep -a "api.deepl.com/v1" >/dev/null; then
        printf '  → API: v1 endpoint (not fixed)\n'
        issue=1
    else
        printf '  → API: custom host\n'
    fi

    if unzip -p "$OMEGAT_DIR/OmegaT.jar" org/omegat/core/machinetranslators/DeepLTranslate.class 2>/dev/null | grep -a "DeepL-Auth-Key" >/dev/null; then
        printf '  → Auth: header (fixed)\n'
    else
        printf '  → Auth: header missing\n'
        issue=1
    fi

    if unzip -p "$OMEGAT_DIR/OmegaT.jar" org/omegat/core/machinetranslators/DeepLTranslate.class 2>/dev/null | grep -a "Mozilla/5.0" >/dev/null; then
        printf '  → Agent: browser-style (fixed)\n'
    else
        printf '  → Agent: browser-style missing\n'
        issue=1
    fi

    echo ""
    if [ "$issue" -eq 0 ]; then
        ok "OmegaT is ready."
        return 0
    else
        warn "OmegaT is not patched."
        return 1
    fi
}

cmd_build() {
    detect_omegat_dir || die "OmegaT not found. Open OmegaT once and run again."
    [ -f "$OMEGAT_DIR/OmegaT.jar" ] || die "OmegaT.jar not found"
    [ -d "$OMEGAT_DIR/lib" ] || die "OmegaT appears incomplete"
    [ -f "$PATCH_CLASS" ] || die "Patch file missing"

    command -v lsof >/dev/null 2>&1 && lsof "$OMEGAT_DIR/OmegaT.jar" >/dev/null 2>&1 && die "OmegaT is open. Close it and run again."
    command -v zip >/dev/null 2>&1 || die "zip not found."
    command -v unzip >/dev/null 2>&1 || die "unzip not found."

    if cmd_check >/dev/null 2>&1; then
        ok "OmegaT is already patched. Nothing to do."
        exit 0
    fi

    ok "Steps: 1. Backup  2. Apply fix  3. Verify"

    [ -n "$DRY_RUN" ] && { echo ""; ok "Dry run done."; exit 0; }

    local BACKUP="$OMEGAT_DIR/OmegaT.jar.bak.$(date +%Y%m%d%H%M%S)"
    cp "$OMEGAT_DIR/OmegaT.jar" "$BACKUP"
    ok "Backup saved"

    local TDIR
    TDIR=$(mktemp -d)
    trap 'rm -rf "$TDIR"' EXIT
    mkdir -p "$TDIR/org/omegat/core/machinetranslators"
    cp "$PATCH_CLASS" "$TDIR/org/omegat/core/machinetranslators/DeepLTranslate.class"
    (cd "$TDIR" && zip -q "$OMEGAT_DIR/OmegaT.jar" org/omegat/core/machinetranslators/DeepLTranslate.class)

    shopt -s nullglob
    local backups=("$OMEGAT_DIR"/OmegaT.jar.bak.*)
    shopt -u nullglob
    local total=${#backups[@]}
    if [ "$total" -gt 3 ]; then
        for ((i=0; i<total-3; i++)); do
            rm -f "${backups[$i]}"
        done
    fi

    echo ""
    cmd_check
    echo ""
    ok "Done. OmegaT is ready."
}

cmd_undo() {
    detect_omegat_dir || die "OmegaT not found. Open OmegaT once and run again."
    [ -f "$OMEGAT_DIR/OmegaT.jar" ] || die "OmegaT.jar not found"

    command -v lsof >/dev/null 2>&1 && lsof "$OMEGAT_DIR/OmegaT.jar" >/dev/null 2>&1 && die "OmegaT is open. Close it and run again."

    shopt -s nullglob
    local backups=("$OMEGAT_DIR"/OmegaT.jar.bak.*)
    shopt -u nullglob
    [ ${#backups[@]} -gt 0 ] || die "No backup found."

    local selected="${backups[0]}"

    if [ -n "$CHOOSE" ] && [ -t 0 ]; then
        echo "Backups:"
        for i in "${!backups[@]}"; do
            printf '  [%s] %s\n' "$((i + 1))" "${backups[$i]}"
        done
        printf '\nChoose [1]: '
        read -r c || true
        c="${c:-1}"
        case "$c" in ''|*[!0-9]*) die "Invalid choice." ;; esac
        [ "$c" -ge 1 ] && [ "$c" -le "${#backups[@]}" ] || die "Invalid choice."
        selected="${backups[$((c - 1))]}"
    fi

    cp "$selected" "$OMEGAT_DIR/OmegaT.jar"
    ok "Restored. OmegaT is back to its original state."
}

case "$MODE" in
    build) cmd_build ;;
    check) cmd_check || exit 1 ;;
    undo)  cmd_undo ;;
esac
