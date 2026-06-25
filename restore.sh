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
        [ -f "$path/OmegaT.jar" ] && [ -d "$path/lib" ] && { OMEGAT_DIR="$path"; ok "OmegaT detected"; return 0; }
    done
    die "OmegaT not found. Open OmegaT once and run again."
}

pick_backup() {
    shopt -s nullglob
    BACKUPS=("$OMEGAT_DIR"/OmegaT.jar.bak.*)
    shopt -u nullglob
    [ ${#BACKUPS[@]} -gt 0 ] || die "No backup found in $OMEGAT_DIR"

    SELECTED="${BACKUPS[0]}"

    if [ "${CHOOSE_BACKUP:-}" = "1" ] && [ -t 0 ]; then
        echo ""
        echo "Backups:"
        for i in "${!BACKUPS[@]}"; do
            printf '  [%s] %s\n' "$((i + 1))" "${BACKUPS[$i]}"
        done
        printf '\nChoose [1]: '
        read -r choice || true
        choice="${choice:-1}"
        case "$choice" in ''|*[!0-9]*) die "Invalid choice." ;; esac
        [ "$choice" -ge 1 ] && [ "$choice" -le "${#BACKUPS[@]}" ] || die "Invalid choice."
        SELECTED="${BACKUPS[$((choice - 1))]}"
    fi
}

if [ "${1:-}" = "--omegat-dir" ] && [ -n "${2:-}" ]; then
    OMEGAT_DIR="$2"
    shift 2
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --choose) CHOOSE_BACKUP="1" ;;
        --help|-h)
            echo "Usage: $0 [--omegat-dir PATH] [--choose]"
            echo "Restores OmegaT to its original state."
            echo "Auto-detects OmegaT if no path is given."
            exit 0
            ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

detect_omegat_dir
pick_backup

cp "$SELECTED" "$OMEGAT_DIR/OmegaT.jar"
ok "Restored. OmegaT is back to its original state."
