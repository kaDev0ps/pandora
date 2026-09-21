#!/usr/bin/env bash
# install_iotop-c.sh – Universal iotop-c installer
# iotop-c = simple top-like I/O monitor (implemented in C)
# Upstream: https://github.com/Tomas-M/iotop
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check privileges — this script is meant to be run as a normal user;
# it elevates only the specific steps that need root, via `sudo -E`
# (the -E preserves your env, e.g. proxy vars, which plain `sudo` resets).
if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo -E"
    else
        error "This script must be run as root or with sudo. Please install sudo or run as root."
    fi
else
    SUDO=""
fi

# Locate iotop-c / iotop binary.
# iotop-c is installed into /usr/sbin on Debian-derived systems (including
# Astra Linux), and /usr/sbin is usually NOT in a non-root user's PATH.
# So check PATH first, then the well-known sbin/local locations.
find_iotop_bin() {
    local cand
    for cand in iotop-c iotop; do
        if command -v "$cand" &>/dev/null; then
            command -v "$cand"; return 0
        fi
        if [[ -x "/usr/sbin/$cand" ]]; then
            echo "/usr/sbin/$cand"; return 0
        fi
        if [[ -x "/sbin/$cand" ]]; then
            echo "/sbin/$cand"; return 0
        fi
        if [[ -x "/usr/local/sbin/$cand" ]]; then
            echo "/usr/local/sbin/$cand"; return 0
        fi
        if [[ -x "/usr/local/bin/$cand" ]]; then
            echo "/usr/local/bin/$cand"; return 0
        fi
    done
    return 1
}

# Already installed?
if IOTOP_BIN="$(find_iotop_bin)"; then
    IOTOP_VER="$("$IOTOP_BIN" --version 2>&1 | head -n1 || true)"
    info "iotop-c is already installed: $IOTOP_BIN — $IOTOP_VER"
    exit 0
fi

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_ID_LIKE="$ID_LIKE"
else
    error "Cannot detect OS – /etc/os-release not found."
fi

info "Detected OS: $NAME $VERSION"

# ---- Package manager installers ----

install_via_apt() {
    info "Trying to install iotop-c via apt..."
    # apt update can report errors on some stale repos (e.g. Astra uu/last)
    # without being fatal — we still only need the package metadata.
    $SUDO apt update || warn "apt update reported errors; continuing anyway..."
    if apt-cache show iotop-c &>/dev/null; then
        $SUDO apt install -y iotop-c
        return 0
    fi
    return 1
}

install_via_dnf() {
    info "Trying to install iotop-c via dnf..."
    if dnf list available iotop-c &>/dev/null; then
        $SUDO dnf install -y iotop-c
        return 0
    fi
    return 1
}

install_via_yum() {
    info "Trying to install iotop-c via yum..."
    # On RHEL/CentOS, iotop-c may be in EPEL
    if ! rpm -q epel-release &>/dev/null; then
        $SUDO yum install -y epel-release &>/dev/null || true
    fi
    if yum list available iotop-c &>/dev/null; then
        $SUDO yum install -y iotop-c
        return 0
    fi
    return 1
}

install_via_zypper() {
    info "Trying to install iotop-c via zypper..."
    if zypper search iotop-c 2>/dev/null | grep -q '^i\? *| *iotop-c'; then
        $SUDO zypper install -y iotop-c
        return 0
    fi
    return 1
}

install_via_pacman() {
    info "Trying to install iotop-c via pacman..."
    $SUDO pacman -Sy --noconfirm
    if pacman -Ss '^iotop-c$' &>/dev/null; then
        $SUDO pacman -S --noconfirm --needed iotop-c
        return 0
    fi
    return 1
}

install_via_apk() {
    info "Trying to install iotop-c via apk..."
    $SUDO apk update
    if apk search iotop-c &>/dev/null; then
        $SUDO apk add iotop-c
        return 0
    fi
    return 1
}

install_via_xbps() {
    info "Trying to install iotop-c via xbps-install..."
    $SUDO xbps-install -Su xbps 2>/dev/null || true
    if xbps-query -Rs iotop-c &>/dev/null; then
        $SUDO xbps-install -y iotop-c
        return 0
    fi
    return 1
}

# ---- Source build fallback (works on any distro) ----

install_from_source() {
    warn "iotop-c not available via package manager. Building from source..."

    # Check for required build tools
    local missing=()
    command -v git  &>/dev/null || missing+=("git")
    command -v make &>/dev/null || missing+=("make")
    command -v gcc  &>/dev/null || missing+=("gcc")

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing build tools: ${missing[*]}. Attempting to install them..."

        if   command -v apt    &>/dev/null; then
            $SUDO apt update || warn "apt update reported errors; continuing anyway..."
            $SUDO apt install -y git build-essential libncurses-dev libncursesw5-dev pkg-config
        elif command -v dnf    &>/dev/null; then
            $SUDO dnf install -y git gcc make ncurses-devel pkgconfig
        elif command -v yum    &>/dev/null; then
            $SUDO yum install -y git gcc make ncurses-devel pkgconfig
        elif command -v zypper &>/dev/null; then
            $SUDO zypper install -y git gcc make ncurses-devel pkg-config
        elif command -v pacman &>/dev/null; then
            $SUDO pacman -S --noconfirm --needed git base-devel ncurses
        elif command -v apk    &>/dev/null; then
            $SUDO apk add git build-base ncurses-dev
        elif command -v xbps-install &>/dev/null; then
            $SUDO xbps-install -y git base-devel ncurses-devel
        else
            error "Cannot install build tools automatically. Please install: git make gcc ncurses-dev (or equivalent) and re-run."
        fi
    fi

    # Clone and build
    local tmpdir
    tmpdir="$(mktemp -d)"
    info "Cloning iotop-c repository..."
    git clone --depth=1 https://github.com/Tomas-M/iotop.git "$tmpdir/iotop" || \
        error "Failed to clone iotop repository."

    info "Building iotop-c..."
    (
        cd "$tmpdir/iotop"
        make -j"$(nproc 2>/dev/null || echo 2)"
        $SUDO make install
    ) || error "Build or installation failed."

    rm -rf "$tmpdir"
}

# ---- Main installation logic: prefer detecting the package manager itself ----

INSTALLED=0

if command -v apt &>/dev/null; then
    install_via_apt && INSTALLED=1
elif command -v dnf &>/dev/null; then
    install_via_dnf && INSTALLED=1
elif command -v yum &>/dev/null; then
    install_via_yum && INSTALLED=1
elif command -v zypper &>/dev/null; then
    install_via_zypper && INSTALLED=1
elif command -v pacman &>/dev/null; then
    install_via_pacman && INSTALLED=1
elif command -v apk &>/dev/null; then
    install_via_apk && INSTALLED=1
elif command -v xbps-install &>/dev/null; then
    install_via_xbps && INSTALLED=1
fi

if [[ "$INSTALLED" -ne 1 ]]; then
    install_from_source
fi

# Verify installation (handle /usr/sbin not being in PATH)
if IOTOP_BIN="$(find_iotop_bin)"; then
    IOTOP_VER="$("$IOTOP_BIN" --version 2>&1 | head -n1 || true)"
    info "iotop-c successfully installed: $IOTOP_BIN — $IOTOP_VER"

    if ! command -v iotop-c &>/dev/null && ! command -v iotop &>/dev/null; then
        warn "'iotop-c' lives in /usr/sbin and is not in your user PATH."
        warn "Run it with:  sudo $IOTOP_BIN"
        warn "Or add sbin to PATH:  export PATH=\"\$PATH:/usr/sbin:/sbin\""
    fi
else
    error "iotop-c installation failed."
fi

info "All done! Run 'sudo iotop-c' (or 'sudo iotop') to see disk I/O usage."
