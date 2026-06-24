#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

DRY_RUN=""
INSTALL_JDK=""
POSITIONAL=()
HELP=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN="1"; shift ;;
        --install-jdk) INSTALL_JDK="1"; shift ;;
        --omegat-dir) OMEGAT_DIR="$2"; shift 2 ;;
        --help|-h) HELP="1"; shift ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done

if [ -z "${OMEGAT_DIR:-}" ] && [ ${#POSITIONAL[@]} -gt 0 ]; then
    OMEGAT_DIR="${POSITIONAL[0]}"
fi

# ---- Detect platform ----
case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *)      err "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

# ---- Help ----
if [ -n "${HELP:-}" ]; then
    cat <<EOF
Usage: $0 [OPTIONS] [--omegat-dir PATH]

Options:
  --omegat-dir PATH  Path to OmegaT directory (auto-detected if omitted)
  --dry-run          Show what would be done without making changes
  --install-jdk      Install JDK 17 if missing (macOS: Homebrew, Linux: dnf)
  -h, --help         Show this help

Auto-detected paths (when --omegat-dir is not given):
  macOS:  /Applications/OmegaT.app/Contents/Java
  Linux:  ~/.local/opt/omegat/OmegaT_*/, ~/omegat/OmegaT_*/,
          /opt/omegat/OmegaT_*/, Flatpak

Examples:
  $0                                # auto-detect everything
  $0 --dry-run                      # preview without changes
  $0 --omegat-dir /path/to/OmegaT   # manual path
  $0 --install-jdk                  # install JDK if missing
EOF
    exit 1
fi

# ---- Auto-detect OmegaT directory ----
if [ -z "${OMEGAT_DIR:-}" ]; then
    CANDIDATES=()

    if [ "$OS" = "macos" ]; then
        CANDIDATES+=("/Applications/OmegaT.app/Contents/Java")
    fi

    if [ "$OS" = "linux" ]; then
        CANDIDATES+=($HOME/.local/opt/omegat/OmegaT_*)
        CANDIDATES+=($HOME/omegat/OmegaT_*)
        CANDIDATES+=(/opt/omegat/OmegaT_*)
        FLATPAK_DIR="/var/lib/flatpak/app/org.omegat.OmegaT/current/active/files/omegat"
        [ -d "$FLATPAK_DIR" ] && CANDIDATES+=("$FLATPAK_DIR")
    fi

    VALID=()
    for d in "${CANDIDATES[@]}"; do
        if [ -f "$d/OmegaT.jar" ] && [ -d "$d/lib" ]; then
            VALID+=("$d")
        fi
    done

    if [ ${#VALID[@]} -eq 0 ]; then
        err "OmegaT not found. Install it manually or pass --omegat-dir."
        exit 1
    elif [ ${#VALID[@]} -eq 1 ]; then
        OMEGAT_DIR="${VALID[0]}"
        log "Auto-detected OmegaT: $OMEGAT_DIR"
    else
        echo -e "${YELLOW}Multiple OmegaT installations found:${NC}"
        for i in "${!VALID[@]}"; do
            echo "  [$((i+1))] ${VALID[$i]}"
        done
        read -rp "Select [1]: " choice
        choice="${choice:-1}"
        OMEGAT_DIR="${VALID[$((choice-1))]}"
    fi
fi

# ---- JDK check ----
ensure_jdk() {
    if command -v javac >/dev/null 2>&1 && command -v jar >/dev/null 2>&1; then
        log "JDK found: $(javac -version 2>&1)"
        return 0
    fi

    if [ -z "${INSTALL_JDK:-}" ]; then
        err "JDK 11+ required (javac + jar). Run with --install-jdk to auto-install,"
        err "or install manually and ensure they are in PATH."
        exit 1
    fi

    if [ "$OS" = "macos" ]; then
        if ! command -v brew >/dev/null 2>&1; then
            warn "Homebrew not found. Installing Homebrew first..."
            if [ -z "$DRY_RUN" ]; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                log "[DRY-RUN] Would install Homebrew"
            fi
        fi
        log "Installing openjdk@17 via Homebrew..."
        if [ -z "$DRY_RUN" ]; then
            brew install openjdk@17
            export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
        else
            log "[DRY-RUN] brew install openjdk@17"
        fi
    elif [ "$OS" = "linux" ]; then
        if command -v dnf >/dev/null 2>&1; then
            log "Installing java-17-openjdk-devel via dnf..."
            if [ -z "$DRY_RUN" ]; then
                sudo dnf install -y java-17-openjdk-devel
            else
                log "[DRY-RUN] sudo dnf install -y java-17-openjdk-devel"
            fi
        else
            err "Auto-install not supported for your Linux distro."
            err "Install JDK 11+ manually and ensure javac/jar are in PATH."
            exit 1
        fi
    fi

    if ! command -v javac >/dev/null 2>&1; then
        err "JDK installation failed. Install JDK 11+ manually."
        exit 1
    fi
    log "JDK ready: $(javac -version 2>&1)"
}

# ---- Validations ----
[ -d "$OMEGAT_DIR" ]      || { err "Directory not found: $OMEGAT_DIR"; exit 1; }
[ -f "$OMEGAT_DIR/OmegaT.jar" ] || { err "OmegaT.jar not found in $OMEGAT_DIR"; exit 1; }
[ -d "$OMEGAT_DIR/lib" ]  || { err "lib/ not found in $OMEGAT_DIR"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patch/org/omegat/core/machinetranslators/DeepLTranslate.java"
[ -f "$PATCH_FILE" ]      || { err "Patch source not found: $PATCH_FILE"; exit 1; }

if command -v lsof >/dev/null 2>&1 && lsof "$OMEGAT_DIR/OmegaT.jar" >/dev/null 2>&1; then
    err "OmegaT is running. Close it before patching."
    exit 1
fi

# ---- JDK (after validations, before plan) ----
echo ""
ensure_jdk

# ---- Classpath ----
CLASSPATH="$OMEGAT_DIR/OmegaT.jar"
for jar in "$OMEGAT_DIR"/lib/*.jar; do
    CLASSPATH="$CLASSPATH:$jar"
done

# ---- Plan ----
echo ""
echo -e "${CYAN}Plan:${NC}"
echo "  OS:        $OS"
echo "  OmegaT:    $OMEGAT_DIR"
echo "  JDK:       $(javac -version 2>&1)"
echo "  Backup:    OmegaT.jar.bak.<timestamp>"
echo "  Compile:   javac -cp ... $(basename "$PATCH_FILE")"
echo "  Patch:     jar uf OmegaT.jar .../DeepLTranslate.class"
echo "  Verify:    jar tf OmegaT.jar | grep DeepLTranslate.class"

if [ -n "$DRY_RUN" ]; then
    echo ""
    log "DRY RUN complete — no changes were made."
    exit 0
fi

# ---- Execute ----
BACKUP="$OMEGAT_DIR/OmegaT.jar.bak.$(date +%Y%m%d%H%M%S)"
cp "$OMEGAT_DIR/OmegaT.jar" "$BACKUP"
log "Backup created: $BACKUP"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$SCRIPT_DIR/patch"/* "$TMPDIR/"
javac -cp "$CLASSPATH" "$TMPDIR"/org/omegat/core/machinetranslators/DeepLTranslate.java

CLASS_FILE="$TMPDIR/org/omegat/core/machinetranslators/DeepLTranslate.class"
[ -f "$CLASS_FILE" ] || { err "Compilation failed (no .class produced)"; exit 1; }

jar uf "$OMEGAT_DIR/OmegaT.jar" -C "$TMPDIR" org/omegat/core/machinetranslators/DeepLTranslate.class

jar tf "$OMEGAT_DIR/OmegaT.jar" | grep -q "DeepLTranslate.class" \
    || { err "Patch verification failed"; exit 1; }

log "Done! DeepLTranslate patched successfully."
