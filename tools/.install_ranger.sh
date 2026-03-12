#!/usr/bin/env bash
# install_ranger.sh – Universal ranger installer with bookmarks setup
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

# Function: install via pip
install_via_pip() {
    warn "Attempting installation via pip (fallback method)..."
    if ! command -v pip3 &>/dev/null; then
        info "Installing python3-pip first..."
        if [[ "$OS_ID" == "altlinux" ]] || [[ "$OS_ID_LIKE" == *"altlinux"* ]]; then
            $SUDO apt-get install -y python3-pip
        else
            $SUDO apt install -y python3-pip
        fi
    fi
    $SUDO pip3 install ranger-fm
}

# Function: install via apt (Debian/Ubuntu/Astra)
install_via_apt() {
    info "Trying to install ranger via apt..."
    $SUDO apt update
    if apt-cache show ranger &>/dev/null; then
        $SUDO apt install -y ranger
    else
        warn "Package 'ranger' not found in repositories. Falling back to pip."
        install_via_pip
    fi
}

# Function: install via apt-get (ALT Linux)
install_via_apt_alt() {
    info "Trying to install ranger via apt-get (ALT)..."
    $SUDO apt-get update
    if apt-cache show ranger &>/dev/null; then
        $SUDO apt-get install -y ranger
    else
        warn "Package 'ranger' not found in ALT repositories. Falling back to pip."
        install_via_pip
    fi
}

# Main installation logic
case "$OS_ID" in
    ubuntu|debian)
        install_via_apt
        ;;
    astra)
        info "Astra Linux detected. Attempting apt installation (may need repositories enabled)."
        install_via_apt   # will fallback to pip if apt fails
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
            warn "Unknown OS. Attempting pip installation directly."
            install_via_pip
        fi
        ;;
esac

# Verify installation
if command -v ranger &>/dev/null; then
    info "ranger successfully installed: $(ranger --version)"
else
    error "ranger installation failed."
fi

# ----- Set up bookmarks file -----
setup_bookmarks() {
    local ranger_config_dir="$HOME/.config/ranger"
    local bookmarks_file="$ranger_config_dir/bookmarks"

    if [ ! -d "$ranger_config_dir" ]; then
        mkdir -p "$ranger_config_dir"
        info "Created ranger config directory: $ranger_config_dir"
    fi

    if [ ! -f "$bookmarks_file" ]; then
        touch "$bookmarks_file"
        info "Created empty bookmarks file: $bookmarks_file"
    else
        info "Bookmarks file already exists: $bookmarks_file"
    fi
}

setup_bookmarks

info "All done! You can now start ranger and add bookmarks with 'm<key>'."
