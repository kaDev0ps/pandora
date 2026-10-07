#!/usr/bin/env bash
# install_toolkit.sh – Universal CLI toolkit installer (Debian/Ubuntu/Astra + ALT Linux)
#
# Strategy for every tool:
#   1. already installed?            -> skip
#   2. try distro packages (apt-get) -> first candidate package name that exists in the repos
#   3. fallback: GitHub release binary (-> /usr/local/bin), can be disabled with --no-github
# At the end a checklist shows what is installed and what is missing.
#
# Usage:  ./install_toolkit.sh [--no-github] [--check-only] [-h|--help]

set -uo pipefail
export PATH="$PATH:/usr/local/bin:/usr/local/sbin:/usr/sbin:/sbin"

# ---------------------------------------------------------------- colors/log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---------------------------------------------------------------- options
USE_GITHUB=1
CHECK_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --no-github)  USE_GITHUB=0 ;;
        --check-only) CHECK_ONLY=1 ;;
        -h|--help)
            sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) error "Unknown option: $arg (try --help)" ;;
    esac
done

# ---------------------------------------------------------------- tool list
# Format: "name|binaries (any of them counts)|package candidates (first one found wins)|github key"
# Lines starting with '#' are category headers.
TOOLS=(
"# Productivity & Navigation"
"zoxide|zoxide|zoxide|zoxide"
"eza|eza|eza|eza"
"ripgrep|rg|ripgrep|"
"fd|fd fdfind|fd-find fd|"
"bat|bat batcat|bat|"
"delta|delta|git-delta delta|delta"
"yazi|yazi|yazi|yazi"
"fastfetch|fastfetch|fastfetch|fastfetch"

"# Process, CPU & Memory Debugging"
"lsof|lsof|lsof|"
"vmstat|vmstat|procps procps-ng|"
"mpstat|mpstat|sysstat|"

"# Logs & Web Analytics"
"lnav|lnav|lnav|"
"lazyjournal|lazyjournal|lazyjournal|lazyjournal"

"# Networking"
"tshark|tshark|tshark wireshark-cli|"
"mtr|mtr|mtr mtr-tiny|"
"iftop|iftop|iftop|"
"tcpdump|tcpdump|tcpdump|"
"dig|dig|bind9-dnsutils dnsutils bind-utils|"
"xh|xh|xh|xh"
"nc|nc ncat|netcat-openbsd netcat nmap-ncat netcat-traditional|"
"speedtest-cli|speedtest-cli speedtest|speedtest-cli|"

"# Storage, Filesystems & Disk I/O"
"duf|duf|duf|duf"
"ncdu|ncdu|ncdu|"
"iotop-c|iotop-c iotop|iotop-c iotop|"
"smartctl|smartctl|smartmontools|"
)

# ---------------------------------------------------------------- helpers
declare -A METHOD   # name -> how it got installed

is_installed() {            # $1 = space-separated list of binary names
    local b
    for b in $1; do command -v "$b" &>/dev/null && return 0; done
    return 1
}

found_bin() {               # print the first binary found
    local b
    for b in $1; do command -v "$b" 2>/dev/null && return 0; done
    return 1
}

pkg_available() { apt-cache show "$1" 2>/dev/null | grep -q '^Package:'; }

# ---------------------------------------------------------------- privileges
if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then SUDO="sudo"
    else
        [[ $CHECK_ONLY -eq 1 ]] || error "Run as root or with sudo (sudo is not installed)."
        SUDO=""
    fi
else
    SUDO=""
fi

# ---------------------------------------------------------------- OS detection
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"; OS_ID_LIKE="${ID_LIKE:-}"
else
    error "Cannot detect OS – /etc/os-release not found."
fi
info "Detected OS: ${NAME:-$OS_ID} ${VERSION:-}"

FAMILY=""
case "$OS_ID" in
    ubuntu|debian|astra|linuxmint|raspbian) FAMILY="debian" ;;
    altlinux|alt)                           FAMILY="alt" ;;
    *)
        if   [[ "$OS_ID_LIKE" == *debian* || "$OS_ID_LIKE" == *ubuntu* ]]; then FAMILY="debian"
        elif [[ "$OS_ID_LIKE" == *alt* ]]; then FAMILY="alt"
        fi ;;
esac
if [[ -z "$FAMILY" && $CHECK_ONLY -eq 0 ]]; then
    error "Unsupported OS family ($OS_ID). Only Debian-like and ALT Linux are supported."
fi

# ---------------------------------------------------------------- architecture
case "$(uname -m)" in
    x86_64|amd64)  GH_X="x86_64";  GH_GO="amd64"; GH_DUF="x86_64"; GH_FF="amd64" ;;
    aarch64|arm64) GH_X="aarch64"; GH_GO="arm64"; GH_DUF="arm64";  GH_FF="aarch64" ;;
    *) GH_X=""; USE_GITHUB=0; warn "Architecture $(uname -m) not supported for GitHub fallback." ;;
esac

# ---------------------------------------------------------------- GitHub fallback
gh_spec() {   # sets GH_REPO, GH_RE (asset regex), GH_BINS (binaries to install)
    case "$1" in
        zoxide)      GH_REPO="ajeetdsouza/zoxide";     GH_RE="${GH_X}-unknown-linux-musl\.tar\.gz$";     GH_BINS="zoxide" ;;
        eza)         GH_REPO="eza-community/eza";      GH_RE="eza_${GH_X}-unknown-linux-musl\.tar\.gz$"; GH_BINS="eza" ;;
        delta)       GH_REPO="dandavison/delta";       GH_RE="${GH_X}-unknown-linux-musl\.tar\.gz$";     GH_BINS="delta" ;;
        yazi)        GH_REPO="sxyazi/yazi";            GH_RE="yazi-${GH_X}-unknown-linux-musl\.zip$";    GH_BINS="yazi ya" ;;
        xh)          GH_REPO="ducaale/xh";             GH_RE="${GH_X}-unknown-linux-musl\.tar\.gz$";     GH_BINS="xh" ;;
        duf)         GH_REPO="muesli/duf";             GH_RE="linux_${GH_DUF}\.tar\.gz$";                GH_BINS="duf" ;;
        fastfetch)   GH_REPO="fastfetch-cli/fastfetch"; GH_RE="fastfetch-linux-${GH_FF}\.tar\.gz$";      GH_BINS="fastfetch" ;;
        lazyjournal) GH_REPO="Lifailon/lazyjournal";   GH_RE="linux-${GH_GO}$";                          GH_BINS="lazyjournal" ;;
        *) return 1 ;;
    esac
}

gh_install() {
    local key="$1" tmp url b src
    gh_spec "$key" || return 1
    local auth=()
    [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

    url=$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$GH_REPO/releases/latest" 2>/dev/null \
          | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 | grep -E "$GH_RE" | head -1)
    [[ -n "$url" ]] || return 1

    tmp=$(mktemp -d)
    if ! curl -fsSL "$url" -o "$tmp/asset"; then rm -rf "$tmp"; return 1; fi

    case "$url" in
        *.tar.gz) tar -xzf "$tmp/asset" -C "$tmp" || { rm -rf "$tmp"; return 1; } ;;
        *.zip)    unzip -q "$tmp/asset" -d "$tmp"  || { rm -rf "$tmp"; return 1; } ;;
        *)        mv "$tmp/asset" "$tmp/${GH_BINS%% *}" ;;      # raw binary
    esac

    for b in $GH_BINS; do
        src=$(find "$tmp" -type f -name "$b" | head -1)
        if [[ -n "$src" ]]; then
            $SUDO install -m 0755 "$src" "/usr/local/bin/$b" || { rm -rf "$tmp"; return 1; }
        fi
    done
    rm -rf "$tmp"
    return 0
}

# ---------------------------------------------------------------- package install
apt_install() {   # install the first available package candidate; returns 0 on success
    local p
    for p in $1; do
        if pkg_available "$p"; then
            info "  -> apt-get install $p"
            if $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" >/dev/null 2>&1; then
                return 0
            fi
            warn "  package '$p' found but installation failed"
        fi
    done
    return 1
}

fix_aliases() {   # Debian ships fd as 'fdfind' and bat as 'batcat' – add normal names
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        $SUDO ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        $SUDO ln -sf "$(command -v batcat)" /usr/local/bin/bat
    fi
}

# ---------------------------------------------------------------- main install
install_all() {
    info "Updating package index..."
    $SUDO apt-get update >/dev/null 2>&1 || warn "apt-get update failed – continuing with the cached index."

    # Helpers needed for the GitHub fallback
    if [[ $USE_GITHUB -eq 1 ]]; then
        local h
        for h in curl ca-certificates tar unzip gzip; do
            command -v "$h" &>/dev/null || apt_install "$h" || true
        done
        command -v curl &>/dev/null || { warn "curl is missing – GitHub fallback disabled."; USE_GITHUB=0; }
    fi

    # Avoid the interactive 'wireshark non-root capture' question on Debian-like systems
    if [[ "$FAMILY" == "debian" ]] && command -v debconf-set-selections &>/dev/null; then
        echo "wireshark-common wireshark-common/install-setuid boolean false" | $SUDO debconf-set-selections 2>/dev/null || true
    fi

    local entry name bins pkgs gh
    for entry in "${TOOLS[@]}"; do
        [[ "$entry" == \#* ]] && { echo -e "\n${BLUE}${entry}${NC}"; continue; }
        IFS='|' read -r name bins pkgs gh <<< "$entry"

        if is_installed "$bins"; then
            METHOD[$name]="already installed"
            info "$name: already installed"
            continue
        fi

        info "$name: installing..."
        if [[ -n "$pkgs" ]] && apt_install "$pkgs"; then
            fix_aliases
            is_installed "$bins" && { METHOD[$name]="package"; continue; }
        fi

        if [[ -n "$gh" && $USE_GITHUB -eq 1 ]]; then
            warn "  not in repositories – trying GitHub release..."
            if gh_install "$gh" && is_installed "$bins"; then
                METHOD[$name]="github binary"
                continue
            fi
        fi
        warn "$name: could not be installed"
    done
}

# ---------------------------------------------------------------- checklist
print_checklist() {
    local entry name bins pkgs gh path ok=0 total=0 missing=()
    echo -e "\n${BLUE}==================== INSTALLATION CHECKLIST ====================${NC}"
    for entry in "${TOOLS[@]}"; do
        if [[ "$entry" == \#* ]]; then echo -e "\n${BLUE}${entry}${NC}"; continue; fi
        IFS='|' read -r name bins pkgs gh <<< "$entry"
        total=$((total+1))
        if path=$(found_bin "$bins"); then
            ok=$((ok+1))
            printf "  ${GREEN}[✔]${NC} %-15s %-28s %s\n" "$name" "$path" "${METHOD[$name]:+(${METHOD[$name]})}"
        else
            missing+=("$name")
            printf "  ${RED}[✘]${NC} %-15s %s\n" "$name" "MISSING"
        fi
    done
    echo -e "\nInstalled: ${ok}/${total}"
    if (( ${#missing[@]} )); then
        warn "Missing: ${missing[*]}"
        warn "Tip: tools that are not in your repos (zoxide, eza, yazi, xh, lazyjournal, ...) are fetched from GitHub; run without --no-github and make sure the host can reach github.com."
        return 1
    fi
    info "All tools are installed."
}

# ---------------------------------------------------------------- run
[[ $CHECK_ONLY -eq 1 ]] || install_all
print_checklist
exit $?
