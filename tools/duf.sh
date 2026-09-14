#!/usr/bin/env bash
# install_duf.sh – Universal duf installer
# duf = Disk Usage/Free utility (https://github.com/muesli/duf)
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

# Already installed?
if command -v duf &>/dev/null; then
    info "duf is already installed: $(duf --version 2>&1 | head -n1)"
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
    info "Trying to install duf via apt..."
    $SUDO apt update
    if apt-cache show duf &>/dev/null; then
        $SUDO apt install -y duf
        return 0
    fi
    return 1
}

install_via_dnf() {
    info "Trying to install duf via dnf..."
    $SUDO dnf install -y duf &>/dev/null
}

install_via_yum() {
    info "Trying to install duf via yum..."
    $SUDO yum install -y duf &>/dev/null
}

install_via_zypper() {
    info "Trying to install duf via zypper..."
    $SUDO zypper install -y duf &>/dev/null
}

install_via_pacman() {
    info "Trying to install duf via pacman..."
    $SUDO pacman -Sy --noconfirm
    $SUDO pacman -S --noconfirm --needed duf &>/dev/null
}

install_via_apk() {
    info "Trying to install duf via apk..."
    $SUDO apk update
    $SUDO apk add duf &>/dev/null
}

install_via_apt_alt() {
    info "Trying to install duf via apt-get (ALT Linux)..."
    $SUDO apt-get update
    if apt-cache show duf &>/dev/null; then
        $SUDO apt-get install -y duf
        return 0
    fi
    return 1
}

# ---- GitHub release binary fallback (works on any distro) ----

install_from_release() {
    warn "duf not available via package manager. Downloading prebuilt release from GitHub..."

    command -v curl &>/dev/null || command -v wget &>/dev/null \
        || error "Need curl or wget to download duf. Please install one and re-run."

    local machine goarch
    machine="$(uname -m)"
    case "$machine" in
        x86_64|amd64)   goarch="amd64" ;;
        aarch64|arm64)  goarch="arm64" ;;
        armv7l|armv6l)  goarch="armv6" ;;
        i386|i686)      goarch="386" ;;
        *) error "Unsupported architecture: $machine. Please install duf manually from https://github.com/muesli/duf/releases" ;;
    esac

    info "Looking up latest duf release..."
    local latest_url="https://github.com/muesli/duf/releases/latest"
    local tag effective_url

    # Resolve the redirect from /releases/latest to get the tag, avoiding
    # api.github.com — that subdomain is blocked/rate-limited on some
    # networks even when plain github.com works fine.
    if command -v curl &>/dev/null; then
        effective_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "$latest_url")"
    else
        effective_url="$(wget -q --max-redirect=20 -O /dev/null --server-response "$latest_url" 2>&1 \
            | awk '/^  Location: /{loc=$2} END{print loc}')"
    fi
    tag="${effective_url##*/}"

    if [[ -z "$tag" || "$tag" == "latest" ]]; then
        warn "Could not resolve tag via github.com redirect, trying api.github.com..."
        local api_url="https://api.github.com/repos/muesli/duf/releases/latest"
        if command -v curl &>/dev/null; then
            tag="$(curl -fsSL "$api_url" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
        else
            tag="$(wget -qO- "$api_url" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
        fi
    fi
    [[ -n "$tag" ]] || error "Could not determine latest duf release tag."

    local ver="${tag#v}"
    local base_url="https://github.com/muesli/duf/releases/download/${tag}"
    local tmpdir download
    tmpdir="$(mktemp -d)"

    fetch() {  # fetch <url> <output-file> — returns nonzero on failure, no error() (allow trying next format)
        if command -v curl &>/dev/null; then
            curl -fsSL "$1" -o "$2"
        else
            wget -q "$1" -O "$2"
        fi
    }

    # Not every architecture gets a plain .tar.gz in every release (e.g. amd64/386
    # currently only ship as .deb/.rpm/.apk), so pick the asset that matches both
    # this system's arch AND its native package format, and install accordingly.
    if command -v dpkg &>/dev/null; then
        download="${base_url}/duf_${ver}_linux_${goarch}.deb"
        info "Downloading duf ${tag} (.deb) for linux/${goarch}..."
        fetch "$download" "$tmpdir/duf.deb" || error "Download failed from $download"
        $SUDO dpkg -i "$tmpdir/duf.deb" || error "dpkg failed to install the downloaded .deb"
    elif command -v rpm &>/dev/null; then
        download="${base_url}/duf_${ver}_linux_${goarch}.rpm"
        info "Downloading duf ${tag} (.rpm) for linux/${goarch}..."
        fetch "$download" "$tmpdir/duf.rpm" || error "Download failed from $download"
        $SUDO rpm -Uvh --force "$tmpdir/duf.rpm" || error "rpm failed to install the downloaded package"
    elif command -v apk &>/dev/null; then
        download="${base_url}/duf_${ver}_linux_${goarch}.apk"
        info "Downloading duf ${tag} (.apk) for linux/${goarch}..."
        fetch "$download" "$tmpdir/duf.apk" || error "Download failed from $download"
        $SUDO apk add --allow-untrusted "$tmpdir/duf.apk" || error "apk failed to install the downloaded package"
    else
        # Generic fallback: try the plain tar.gz binary archive (only published
        # for some architectures — arm64/armv6 at the time of writing).
        download="${base_url}/duf_${ver}_linux_${goarch}.tar.gz"
        info "No known package manager found. Trying plain binary tarball for linux/${goarch}..."
        if fetch "$download" "$tmpdir/duf.tar.gz"; then
            tar -xzf "$tmpdir/duf.tar.gz" -C "$tmpdir"
            [[ -f "$tmpdir/duf" ]] || error "Extracted archive did not contain a 'duf' binary."
            $SUDO install -m 755 "$tmpdir/duf" /usr/local/bin/duf
        else
            error "No .tar.gz asset available for linux/${goarch} and no dpkg/rpm/apk found to use the .deb/.rpm/.apk package. Install duf manually from https://github.com/muesli/duf/releases"
        fi
    fi

    rm -rf "$tmpdir"
}

# ---- Main installation logic: prefer detecting the package manager itself ----

INSTALLED=0

if command -v apt &>/dev/null && [[ "$OS_ID" != "altlinux" ]]; then
    install_via_apt && INSTALLED=1
elif command -v apt-get &>/dev/null && [[ "$OS_ID" == "altlinux" ]]; then
    install_via_apt_alt && INSTALLED=1
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
fi

if [[ "$INSTALLED" -ne 1 ]]; then
    install_from_release
fi

# Verify installation
if command -v duf &>/dev/null; then
    info "duf successfully installed: $(duf --version 2>&1 | head -n1)"
else
    error "duf installation failed."
fi

info "All done! Run 'duf' to see your disk usage."
