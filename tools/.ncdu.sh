#!/usr/bin/env bash
# install_ncdu.sh – Universal ncdu installer
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check privileges
if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        error "This script must be run as root or with sudo. Please install sudo or run as root."
    fi
else
    SUDO=""
fi

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_ID_LIKE="$ID_LIKE"
    OS_VERSION_ID="$VERSION_ID"
else
    error "Cannot detect OS – /etc/os-release not found."
fi

info "Detected OS: $NAME $VERSION"

# Function: install via apt (Debian/Ubuntu/Astra)
install_via_apt() {
    info "Trying to install ncdu via apt..."
    $SUDO apt update
    if apt-cache show ncdu &>/dev/null; then
        $SUDO apt install -y ncdu
    else
        error "Package 'ncdu' not found in repositories. Cannot install."
    fi
}

# Function: install via apt-get (ALT Linux)
install_via_apt_alt() {
    info "Trying to install ncdu via apt-get (ALT)..."
    $SUDO apt-get update
    if apt-cache show ncdu &>/dev/null; then
        $SUDO apt-get install -y ncdu
    else
        error "Package 'ncdu' not found in ALT repositories. Cannot install."
    fi
}

# Main installation logic
case "$OS_ID" in
    ubuntu|debian)
        install_via_apt
        ;;
    astra)
        info "Astra Linux detected. Attempting apt installation (may need repositories enabled)."
        install_via_apt
        ;;
    altlinux)
        install_via_apt_alt
        ;;
    *)
        if [[ "$OS_ID_LIKE" == *"debian"* ]] || [[ "$OS_ID_LIKE" == *"ubuntu"* ]]; then
            install_via_apt
        elif [[ "$OS_ID_LIKE" == *"altlinux"* ]]; then
            install_via_apt_alt
        else
            error "Unsupported OS. Please install ncdu manually."
        fi
        ;;
esac

# Verify installation
if command -v ncdu &>/dev/null; then
    info "ncdu successfully installed: $(ncdu --version)"
else
    error "ncdu installation failed."
fi

info "All done! Run 'ncdu /path' to analyse disk usage."
