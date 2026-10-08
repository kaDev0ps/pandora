#!/usr/bin/env bash
# install_toolkit.sh – Universal CLI toolkit installer (Debian/Ubuntu/Astra + ALT Linux)
#
# Strategy for every tool:
#   1. already installed?            -> skip
#   2. try distro packages (apt-get) -> first candidate package name that exists in the repos
#   3. fallback: upstream release binary (-> /usr/local/bin), can be disabled with --no-github
# At the end a checklist shows what is installed and what is missing.
#
# Usage:  ./install_toolkit.sh [--no-github] [--github-only] [--check-only] [-h|--help]

set -uo pipefail
export PATH="$PATH:/usr/local/bin:/usr/local/sbin:/usr/sbin:/sbin"

# ---------------------------------------------------------------- colors/log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---------------------------------------------------------------- options
USE_GITHUB=1
GH_ONLY=0
CHECK_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --no-github)   USE_GITHUB=0 ;;
        --github-only) GH_ONLY=1 ;;
        --check-only)  CHECK_ONLY=1 ;;
        -h|--help)
            awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"
            exit 0 ;;
        *) error "Unknown option: $arg (try --help)" ;;
    esac
done
[[ $USE_GITHUB -eq 0 && $GH_ONLY -eq 1 ]] && error "--no-github and --github-only cannot be combined."

# ---------------------------------------------------------------- tool list
# Format: "name|binaries (any of them counts)|package candidates (first one found wins)|download key"
# Lines starting with '#' are category headers.
TOOLS=(
"# Productivity & Navigation"
"zoxide|zoxide|zoxide|zoxide"
"eza|eza|eza|eza"
"ripgrep|rg|ripgrep|ripgrep"
"fd|fd fdfind|fd-find fd|fd"
"bat|bat batcat|bat|bat"
"delta|delta|git-delta delta|delta"
"yazi|yazi|yazi|yazi"
"fastfetch|fastfetch|fastfetch|fastfetch"

"# Process, CPU & Memory Debugging"
"lsof|lsof|lsof|"
"vmstat|vmstat|procps procps-ng|"
"mpstat|mpstat|sysstat|"

"# Logs & Web Analytics"
"lnav|lnav|lnav|lnav"
"lazyjournal|lazyjournal|lazyjournal|lazyjournal"

"# Networking"
"tshark|tshark|tshark wireshark-cli|"
"mtr|mtr|mtr mtr-tiny|"
"iftop|iftop|iftop|"
"tcpdump|tcpdump|tcpdump|"
"dig|dig|bind9-dnsutils dnsutils bind-utils|"
"xh|xh|xh|xh"
"nc|nc ncat|netcat-openbsd netcat nmap-ncat netcat-traditional|"
"speedtest-cli|speedtest-cli speedtest|speedtest-cli|speedtest-cli"

"# Storage, Filesystems & Disk I/O"
"duf|duf|duf|duf"
"ncdu|ncdu|ncdu|ncdu"
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
info "Detected OS: ${NAME:-$OS_ID} ${VERSION:-${VERSION_ID:-}}"

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
    x86_64|amd64)  GH_X="x86_64";  GH_GO="amd64"; GH_DUF="x86_64"; GH_FF="amd64";   GH_LN="x86_64" ;;
    aarch64|arm64) GH_X="aarch64"; GH_GO="arm64"; GH_DUF="arm64";  GH_FF="aarch64"; GH_LN="arm64" ;;
    *) GH_X=""; USE_GITHUB=0; warn "Architecture $(uname -m) is not supported by the binary fallback." ;;
esac

# ---------------------------------------------------------------- binary fallback
# Special URL resolvers (for projects that are not on GitHub releases)
ncdu_url() {
    local f
    f=$(curl -fsSL https://dev.yorhel.nl/ncdu 2>/dev/null \
        | grep -oE "ncdu-[0-9]+(\.[0-9]+)+-linux-${GH_X}\.tar\.gz" | sort -uV | tail -1)
    [[ -n "$f" ]] && echo "https://dev.yorhel.nl/download/$f"
}
speedtest_url() { echo "https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py"; }

gh_spec() {   # sets GH_REPO, GH_RES (asset regexes, tried in order), GH_BINS, GH_URLFN
    GH_REPO=""; GH_RES=""; GH_BINS=""; GH_URLFN=""
    local musl="${GH_X}-unknown-linux-musl\.tar\.gz\$" gnu="${GH_X}-unknown-linux-gnu\.tar\.gz\$"
    case "$1" in
        zoxide)        GH_REPO="ajeetdsouza/zoxide";      GH_RES="$musl";                         GH_BINS="zoxide" ;;
        eza)           GH_REPO="eza-community/eza";       GH_RES="eza_$musl eza_$gnu";            GH_BINS="eza" ;;
        delta)         GH_REPO="dandavison/delta";        GH_RES="$musl $gnu";                    GH_BINS="delta" ;;
        ripgrep)       GH_REPO="BurntSushi/ripgrep";      GH_RES="$musl $gnu";                    GH_BINS="rg" ;;
        fd)            GH_REPO="sharkdp/fd";              GH_RES="$musl $gnu";                    GH_BINS="fd" ;;
        bat)           GH_REPO="sharkdp/bat";             GH_RES="$musl $gnu";                    GH_BINS="bat" ;;
        yazi)          GH_REPO="sxyazi/yazi";             GH_RES="yazi-${GH_X}-unknown-linux-musl\.zip\$"; GH_BINS="yazi ya" ;;
        xh)            GH_REPO="ducaale/xh";              GH_RES="$musl";                         GH_BINS="xh" ;;
        duf)           GH_REPO="muesli/duf";              GH_RES="linux_${GH_DUF}\.tar\.gz\$";    GH_BINS="duf" ;;
        fastfetch)     GH_REPO="fastfetch-cli/fastfetch"; GH_RES="fastfetch-linux-${GH_FF}\.tar\.gz\$"; GH_BINS="fastfetch" ;;
        lazyjournal)   GH_REPO="Lifailon/lazyjournal";    GH_RES="linux-${GH_GO}\$";              GH_BINS="lazyjournal" ;;
        lnav)          GH_REPO="tstack/lnav";             GH_RES="linux-musl-${GH_LN}\.zip\$";    GH_BINS="lnav" ;;
        ncdu)          GH_URLFN="ncdu_url";               GH_BINS="ncdu" ;;
        speedtest-cli) GH_URLFN="speedtest_url";          GH_BINS="speedtest-cli" ;;
        *) return 1 ;;
    esac
}

smoke_test() {   # does the binary actually start? (catches noexec / digsig / libc problems)
    local f
    for f in --version -V -v -h; do
        timeout 10 "$1" $f </dev/null >/dev/null 2>&1 && return 0
    done
    return 1
}

# List release asset URLs of a GitHub repo. Uses the web pages first (no API rate limit,
# important when many hosts share one NAT address), the REST API only as a fallback.
gh_assets() {
    local repo="$1" tag html
    tag=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest" 2>/dev/null)
    if [[ "$tag" == */tag/* ]]; then
        tag="${tag##*/tag/}"
        html=$(curl -fsSL "https://github.com/$repo/releases/expanded_assets/$tag" 2>/dev/null)
        echo "$html" | grep -oE "href=\"/$repo/releases/download/[^\"]+\"" \
            | sed -e 's|^href="|https://github.com|' -e 's|"$||' | grep . && return 0
    fi
    local auth=()
    [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4
}

GH_RUNS=1
gh_install() {
    local key="$1" tmp url="" b src assets re
    GH_RUNS=1
    gh_spec "$key" || return 1

    if [[ "$key" == "speedtest-cli" ]] && ! command -v python3 &>/dev/null; then
        warn "  python3 is required for speedtest-cli"; return 1
    fi

    if [[ -n "$GH_URLFN" ]]; then
        url=$($GH_URLFN)
    else
        assets=$(gh_assets "$GH_REPO")
        [[ -n "$assets" ]] || return 1
        for re in $GH_RES; do
            url=$(echo "$assets" | grep -E "$re" | head -1)
            [[ -n "$url" ]] && break
        done
    fi
    [[ -n "$url" ]] || return 1

    tmp=$(mktemp -d)
    if ! curl -fsSL "$url" -o "$tmp/asset"; then rm -rf "$tmp"; return 1; fi

    case "$url" in
        *.tar.gz) tar -xzf "$tmp/asset" -C "$tmp" || { rm -rf "$tmp"; return 1; } ;;
        *.zip)    unzip -q "$tmp/asset" -d "$tmp"  || { rm -rf "$tmp"; return 1; } ;;
        *)        mv "$tmp/asset" "$tmp/${GH_BINS%% *}" ;;      # single file / raw binary
    esac
    [[ "$key" == "speedtest-cli" ]] && sed -i '1s|.*|#!/usr/bin/env python3|' "$tmp/speedtest-cli"

    for b in $GH_BINS; do
        src=$(find "$tmp" -type f -name "$b" | head -1)
        [[ -n "$src" ]] || { rm -rf "$tmp"; return 1; }
        $SUDO install -m 0755 "$src" "/usr/local/bin/$b" || { rm -rf "$tmp"; return 1; }
    done
    rm -rf "$tmp"

    smoke_test "/usr/local/bin/${GH_BINS%% *}" || GH_RUNS=0
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
    warn "  none of [$1] is available in the configured repositories"
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

    # Helpers needed for the binary fallback
    if [[ $USE_GITHUB -eq 1 ]]; then
        local h
        for h in curl ca-certificates tar unzip gzip; do
            command -v "$h" &>/dev/null || apt_install "$h" || true
        done
        command -v curl &>/dev/null || { warn "curl is missing – binary fallback disabled."; USE_GITHUB=0; }
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
        if [[ -n "$pkgs" ]] && ! { [[ $GH_ONLY -eq 1 && $USE_GITHUB -eq 1 && -n "$gh" ]]; }; then
            if apt_install "$pkgs"; then
                fix_aliases
                is_installed "$bins" && { METHOD[$name]="package"; continue; }
            fi
        fi

        if [[ -n "$gh" && $USE_GITHUB -eq 1 ]]; then
            warn "  trying upstream release binary..."
            if gh_install "$gh" && is_installed "$bins"; then
                if [[ $GH_RUNS -eq 1 ]]; then
                    METHOD[$name]="github binary"
                else
                    METHOD[$name]="binary installed but FAILS TO START"
                    warn "$name: binary was installed but does not start (noexec mount? Astra digital-signature check?)"
                fi
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
        warn "Tools missing from your repos are downloaded from upstream (github.com, dev.yorhel.nl); make sure the host can reach them, or enable the extra distro repositories."
        return 1
    fi
    info "All tools are installed."
}

# ---------------------------------------------------------------- run
[[ $CHECK_ONLY -eq 1 ]] || install_all
print_checklist
exit $?
