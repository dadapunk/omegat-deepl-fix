#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf '%b→%b %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%b→%b %s\n' "$YELLOW" "$NC" "$*"; }
err()  { printf '%b→%b %s\n' "$RED" "$NC" "$*" >&2; }
die()  { err "$1"; exit 1; }

DRY_RUN=""
HELP=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN="1"; shift ;;
        --omegat-dir) OMEGAT_DIR="$2"; shift 2 ;;
        --help|-h) HELP="1"; shift ;;
        *) die "Unknown option: $1" ;;
    esac
done

case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *) die "Only macOS and Linux are supported." ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patch/org/omegat/core/machinetranslators/DeepLTranslate.java"
VERIFY_SCRIPT="$SCRIPT_DIR/verify.sh"

confirm() {
    question="$1"
    default="${2:-N}"
    [ ! -t 0 ] && return 1
    suffix="[y/N]"; [ "$default" = "Y" ] && suffix="[Y/n]"
    printf '%s %s ' "$question" "$suffix"
    read -r answer || true
    case "${answer:-$default}" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

select_number() {
    default="${1:-1}"
    [ ! -t 0 ] && { printf '%s\n' "$default"; return 0; }
    printf 'Choose [%s]: ' "$default"
    read -r choice || true
    printf '%s\n' "${choice:-$default}"
}

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
    valid=()
    for path in "${candidates[@]}"; do
        [ -f "$path/OmegaT.jar" ] && [ -d "$path/lib" ] && valid+=("$path")
    done
    [ ${#valid[@]} -gt 0 ] || die "OmegaT not found. Open OmegaT once and run again."
    if [ ${#valid[@]} -eq 1 ]; then
        OMEGAT_DIR="${valid[0]}"
        ok "OmegaT detected"
        return 0
    fi
    warn "Multiple copies of OmegaT found:"
    for i in "${!valid[@]}"; do
        printf '  [%s] %s\n' "$((i + 1))" "${valid[$i]}"
    done
    idx="$(select_number 1)"
    case "$idx" in ''|*[!0-9]*) die "Invalid choice." ;; esac
    [ "$idx" -ge 1 ] && [ "$idx" -le "${#valid[@]}" ] || die "Invalid choice."
    OMEGAT_DIR="${valid[$((idx - 1))]}"
    ok "OmegaT detected"
}

ensure_jdk() {
    command -v javac >/dev/null 2>&1 && command -v jar >/dev/null 2>&1 && { ok "Java ready"; return 0; }
    [ -n "$DRY_RUN" ] && { warn "Java not found (skipping, dry run)"; return 0; }
    if [ "$OS" = "macos" ]; then
        if ! command -v brew >/dev/null 2>&1; then
            confirm "Install Homebrew (needed for Java)?" "N" || die "Install Homebrew and run again."
            ok "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
            [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
        fi
        confirm "Install Java 17 now?" "Y" || die "Install Java and run again."
        ok "Installing Java..."
        brew install openjdk@17
        [ -d /opt/homebrew/opt/openjdk@17/bin ] && export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
        [ -d /usr/local/opt/openjdk@17/bin ] && export PATH="/usr/local/opt/openjdk@17/bin:$PATH"
    elif command -v dnf >/dev/null 2>&1; then
        confirm "Install Java with dnf?" "Y" || die "Install Java and run again."
        sudo dnf install -y java-17-openjdk-devel
    else
        die "Java not found. Install Java 11+ and run again."
    fi
    command -v javac >/dev/null 2>&1 && command -v jar >/dev/null 2>&1 || die "Java install failed."
    ok "Java ready"
}

show_help() {
    cat <<EOF
Usage: $0 [--dry-run] [--omegat-dir PATH]

Options:
  --omegat-dir PATH  OmegaT location (auto-detected if omitted)
  --dry-run          Preview without changing anything
  -h, --help         Show this help

Examples:
  $0              Patch OmegaT
  $0 --dry-run    Preview first
EOF
}

[ -n "$HELP" ] && { show_help; exit 0; }
[ -z "$DRY_RUN" ] && [ -t 0 ] && { printf '\nPress Enter to start, or Ctrl+C to cancel.'; read -r _; }

detect_omegat_dir
[ -d "$OMEGAT_DIR" ] || die "OmegaT folder not found"
[ -f "$OMEGAT_DIR/OmegaT.jar" ] || die "OmegaT.jar not found"
[ -d "$OMEGAT_DIR/lib" ] || die "OmegaT appears incomplete"
[ -f "$PATCH_FILE" ] || die "Patch file missing"
command -v lsof >/dev/null 2>&1 && lsof "$OMEGAT_DIR/OmegaT.jar" >/dev/null 2>&1 && die "OmegaT is open. Close it and run again."

echo ""
ensure_jdk

CLASSPATH="$OMEGAT_DIR/OmegaT.jar"
for jar in "$OMEGAT_DIR"/lib/*.jar; do
    [ -e "$jar" ] || continue
    CLASSPATH="$CLASSPATH:$jar"
done

echo ""
if "$VERIFY_SCRIPT" --omegat-dir "$OMEGAT_DIR"; then
    echo ""
    ok "OmegaT is already patched. Nothing to do."
    exit 0
fi

ok "Steps: 1. Backup  2. Apply fix  3. Verify"

[ -n "$DRY_RUN" ] && { echo ""; ok "Dry run done. No changes made."; exit 0; }

BACKUP="$OMEGAT_DIR/OmegaT.jar.bak.$(date +%Y%m%d%H%M%S)"
cp "$OMEGAT_DIR/OmegaT.jar" "$BACKUP"
ok "Backup saved"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cp -r "$SCRIPT_DIR/patch"/* "$TMPDIR/"
javac -cp "$CLASSPATH" "$TMPDIR"/org/omegat/core/machinetranslators/DeepLTranslate.java
[ -f "$TMPDIR/org/omegat/core/machinetranslators/DeepLTranslate.class" ] || die "Build failed."
jar uf "$OMEGAT_DIR/OmegaT.jar" -C "$TMPDIR" org/omegat/core/machinetranslators/DeepLTranslate.class

"$VERIFY_SCRIPT" --omegat-dir "$OMEGAT_DIR"
echo ""
ok "Done. OmegaT is ready."
