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

BACKUPS=("$OMEGAT_DIR"/OmegaT.jar.bak.*)
if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "Error: no backup found in $OMEGAT_DIR"
    exit 1
fi

echo "Available backups:"
for i in "${!BACKUPS[@]}"; do
    echo "  [$((i+1))] ${BACKUPS[$i]}"
done
echo ""
read -rp "Restore which backup? [1]: " choice
choice="${choice:-1}"
INDEX=$((choice - 1))

if [ "$INDEX" -lt 0 ] || [ "$INDEX" -ge "${#BACKUPS[@]}" ]; then
    echo "Error: invalid selection"
    exit 1
fi

SELECTED="${BACKUPS[$INDEX]}"
cp "$SELECTED" "$OMEGAT_DIR/OmegaT.jar"
echo "[+] Restored: $SELECTED -> $OMEGAT_DIR/OmegaT.jar"
