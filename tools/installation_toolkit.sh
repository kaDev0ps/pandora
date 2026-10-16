#!/usr/bin/env bash
# ============================================================
#  install_toolkit.sh - one installer for the whole admin toolkit
#
#  Works on: Debian family (Ubuntu, Astra), ALT (apt-rpm) and, best effort,
#            RHEL family (Red OS) via dnf/yum.
#  Strategy: 1) already installed -> skip
#            2) distro package (tries several package names per tool)
#            3) GitHub release binary -> /usr/local/bin (x86_64 only,
#               for tools that older repos do not have)
#            fzf is the exception: git clone into ~/.fzf comes first, so that
#            ~/.fzf.bash / ~/.fzf.zsh (key bindings) are generated.
#  Ends with a checklist of every tool. Safe to run again at any time.
#
#  Usage:   ./install_toolkit.sh [options]
#    --aliases      also install ~/.bash_aliases (embedded copy; old one is backed up)
#    --no-github    never download from GitHub (offline / closed network)
#    --only a,b     install only the listed tools, e.g. --only fzf,eza,lnav
#    --list         print the tool list and exit
#    -h, --help     this help
#  Run as a normal user with sudo rights (or as root). Log: /tmp/install_toolkit.*.log
# ============================================================
set -u

GITHUB=1; WITH_ALIASES=0; ONLY=""; LIST=0
while [ $# -gt 0 ]; do
    case "$1" in
        --aliases)   WITH_ALIASES=1 ;;
        --no-github) GITHUB=0 ;;
        --only)      ONLY=",${2:-}," ; shift ;;
        --list)      LIST=1 ;;
        -h|--help)   sed -n '2,/^# =\{20,\}$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)           echo "Unknown option: $1 (try --help)"; exit 2 ;;
    esac
    shift
done

# ---------- Tool table ----------
# name | check commands (any) | packages apt/ALT (tried in order) | packages rpm | GitHub fallback
# "-" = no package; a leading "!" on the GitHub function = try GitHub BEFORE the package
TOOLS=(
"@Shell and editors"
"zsh|zsh|zsh|zsh|"
"tmux|tmux|tmux|tmux|"
"vim|vim|vim vim-console vim-enhanced|vim-enhanced|"
"@Files and navigation"
"ranger|ranger|ranger|ranger|"
"nnn|nnn|nnn|nnn|"
"yazi|yazi|yazi|yazi|gh_yazi"
"zoxide|zoxide|zoxide|zoxide|gh_zoxide"
"eza|eza|eza|eza|gh_eza"
"tree|tree|tree|tree|"
"fzf|fzf|fzf|fzf|!gh_fzf"
"@Search and text"
"ripgrep|rg|ripgrep|ripgrep|gh_rg"
"fd|fd fdfind|fd-find fd|fd-find|gh_fd"
"bat|bat batcat|bat|bat|gh_bat"
"delta|delta|git-delta delta|git-delta|gh_delta"
"jq|jq|jq|jq|"
"fastfetch|fastfetch|fastfetch|fastfetch|gh_fastfetch"
"@Logs and systemd"
"lnav|lnav|lnav|lnav|gh_lnav"
"lazyjournal|lazyjournal|-|-|gh_lazyjournal"
"grc|grc|grc|grc|"
"systemd-manager-tui|systemd-manager-tui|-|-|gh_smt"
"@Monitoring and processes"
"btop|btop|btop|btop|"
"glances|glances|glances|glances|"
"sysstat|mpstat iostat|sysstat|sysstat|"
"procps|vmstat|procps procps-ng|procps-ng|"
"lsof|lsof|lsof|lsof|"
"psmisc|pstree|psmisc|psmisc|"
"strace|strace|strace|strace|"
"@Network"
"iproute2|ss|iproute2 iproute|iproute|"
"netcat|nc ncat|netcat-openbsd netcat nmap-ncat nc|nmap-ncat|"
"mtr|mtr|mtr-tiny mtr|mtr|"
"nmap|nmap|nmap|nmap|"
"tcpdump|tcpdump|tcpdump|tcpdump|"
"tshark|tshark|tshark wireshark-cli|wireshark-cli|"
"iftop|iftop|iftop|iftop|"
"dnstop|dnstop|dnstop|dnstop|"
"vnstat|vnstat|vnstat|vnstat|"
"dig|dig|dnsutils bind9-dnsutils bind-utils|bind-utils|"
"xh|xh|xh|xh|gh_xh"
"speedtest-cli|speedtest-cli|speedtest-cli|speedtest-cli|gh_speedtest"
"wget|wget|wget|wget|"
"curl|curl|curl|curl|"
"rsync|rsync|rsync|rsync|"
"@Disks and storage"
"ncdu|ncdu|ncdu|ncdu|"
"duf|duf|duf|duf|gh_duf"
"iotop|iotop-c iotop|iotop-c iotop|iotop|"
"smartmontools|smartctl|smartmontools|smartmontools|"
)

if [ "$LIST" -eq 1 ]; then
    for line in "${TOOLS[@]}"; do
        case "$line" in @*) printf '\n%s\n' "${line#@}" ;; *) printf '  %s\n' "${line%%|*}" ;; esac
    done
    exit 0
fi

# ---------- Output helpers ----------
LOG="/tmp/install_toolkit.$(date +%Y%m%d-%H%M%S).log"
if [ -t 1 ]; then G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'; else G=; R=; Y=; B=; N=; fi
info() { printf '%s\n' "$*"; }
warn() { printf '%s[warn]%s %s\n' "$Y" "$N" "$*"; }
err()  { printf '%s[err ]%s %s\n' "$R" "$N" "$*" >&2; }

# ---------- Environment ----------
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    command -v sudo >/dev/null 2>&1 || { err "run as root or install sudo"; exit 1; }
    SUDO="sudo"
    sudo -v || { err "sudo authentication failed"; exit 1; }
fi
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -n "$TARGET_HOME" ] || TARGET_HOME="$HOME"

if   command -v apt-get >/dev/null 2>&1; then PM=apt
elif command -v dnf     >/dev/null 2>&1; then PM=dnf
elif command -v yum     >/dev/null 2>&1; then PM=yum
else err "no supported package manager (apt-get, dnf, yum)"; exit 1
fi
OS_NAME="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
ARCH="$(uname -m)"
info "${B}Host:${N} $OS_NAME, $ARCH, package manager: $PM, target user: $TARGET_USER"
info "${B}Log:${N}  $LOG"

if [ "$GITHUB" -eq 1 ] && [ "$ARCH" != "x86_64" ]; then
    warn "GitHub fallbacks are x86_64 only; skipping them on $ARCH"; GITHUB=0
fi
if [ "$GITHUB" -eq 1 ] && ! curl -fsS -m 8 -o /dev/null -I https://github.com >>"$LOG" 2>&1; then
    warn "github.com unreachable (proxy? set https_proxy) - GitHub fallbacks disabled"; GITHUB=0
fi

run_as_user() { if [ "$(id -u)" -eq 0 ] && [ "$TARGET_USER" != "root" ]; then sudo -u "$TARGET_USER" -H "$@"; else "$@"; fi; }

GH_TMP="$(mktemp -d)"; trap 'rm -rf "$GH_TMP"' EXIT

# ---------- Package manager ----------
pm_update() {
    [ "$PM" = apt ] || return 0
    info "Updating package index..."
    $SUDO apt-get update >>"$LOG" 2>&1 || warn "apt-get update failed (repos unreachable?) - continuing"
}
try_pkg() {   # try candidates in order, first that installs wins
    local p
    for p in $1; do
        case "$PM" in
            apt) $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" ;;
            *)   $SUDO "$PM" install -y "$p" ;;
        esac >>"$LOG" 2>&1 && { LAST_HOW="$PM:$p"; return 0; }
    done
    return 1
}
# tshark asks whether non-root users may capture: answer "no" (aliases use sudo)
command -v debconf-set-selections >/dev/null 2>&1 && \
    echo 'wireshark-common wireshark-common/install-setuid boolean false' | $SUDO debconf-set-selections 2>/dev/null

# ---------- GitHub release helpers (x86_64, static musl builds) ----------
GH=https://github.com
gh_tag()  { curl -fsSLI -o /dev/null -w '%{url_effective}' "$GH/$1/releases/latest" | sed 's#.*/tag/##'; }
gh_get()  { curl -fsSL --retry 2 -o "$2" "$1"; }                       # url dest
gh_bin()  { local f="$GH_TMP/bin.$$"; gh_get "$1" "$f" && $SUDO install -m 0755 "$f" "/usr/local/bin/$2"; }
gh_pack() {                                                            # url binary...
    local url="$1" f="$GH_TMP/pkg.$$" d="$GH_TMP/x.$$" b src; shift
    mkdir -p "$d"; gh_get "$url" "$f" || return 1
    case "$url" in
        *.zip)    unzip -q -o "$f" -d "$d" ;;
        *.tar.gz) tar -xzf "$f" -C "$d" ;;
        *)        return 1 ;;
    esac || return 1
    for b in "$@"; do
        src="$(find "$d" -type f -name "$b" -perm /111 | head -n1)"          # real executable, not a completion file
        [ -n "$src" ] || src="$(find "$d" -type f -name "$b" | head -n1)"
        [ -n "$src" ] || return 1
        $SUDO install -m 0755 "$src" "/usr/local/bin/$b" || return 1
    done
    rm -rf "$d" "$f"
}
gh_rg()   { local t; t="$(gh_tag BurntSushi/ripgrep)";    gh_pack "$GH/BurntSushi/ripgrep/releases/download/$t/ripgrep-$t-x86_64-unknown-linux-musl.tar.gz" rg; }
gh_fd()   { local t; t="$(gh_tag sharkdp/fd)";            gh_pack "$GH/sharkdp/fd/releases/download/$t/fd-$t-x86_64-unknown-linux-musl.tar.gz" fd; }
gh_bat()  { local t; t="$(gh_tag sharkdp/bat)";           gh_pack "$GH/sharkdp/bat/releases/download/$t/bat-$t-x86_64-unknown-linux-musl.tar.gz" bat; }
gh_delta(){ local t; t="$(gh_tag dandavison/delta)";      gh_pack "$GH/dandavison/delta/releases/download/$t/delta-$t-x86_64-unknown-linux-musl.tar.gz" delta; }
gh_zoxide(){ local t; t="$(gh_tag ajeetdsouza/zoxide)";   gh_pack "$GH/ajeetdsouza/zoxide/releases/download/$t/zoxide-${t#v}-x86_64-unknown-linux-musl.tar.gz" zoxide; }
gh_xh()   { local t; t="$(gh_tag ducaale/xh)";            gh_pack "$GH/ducaale/xh/releases/download/$t/xh-$t-x86_64-unknown-linux-musl.tar.gz" xh; }
gh_duf()  { local t; t="$(gh_tag muesli/duf)";            gh_pack "$GH/muesli/duf/releases/download/$t/duf_${t#v}_linux_x86_64.tar.gz" duf; }
gh_lnav() { local t; t="$(gh_tag tstack/lnav)";           gh_pack "$GH/tstack/lnav/releases/download/$t/lnav-${t#v}-linux-musl-x86_64.zip" lnav; }
gh_eza()  { gh_pack "$GH/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz" eza; }
gh_yazi() { gh_pack "$GH/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip" yazi ya; }
gh_fastfetch() { gh_pack "$GH/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.tar.gz" fastfetch; }
gh_lazyjournal() { local t; t="$(gh_tag Lifailon/lazyjournal)"; gh_bin "$GH/Lifailon/lazyjournal/releases/download/$t/lazyjournal-$t-linux-amd64" lazyjournal; }
gh_smt()  { gh_bin "$GH/matheus-git/systemd-manager-tui/releases/latest/download/systemd-manager-tui" systemd-manager-tui; }
gh_speedtest() {   # single python script
    command -v python3 >/dev/null 2>&1 || return 1
    local f="$GH_TMP/speedtest.py"
    gh_get "https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py" "$f" || return 1
    sed -i '1s|.*|#!/usr/bin/env python3|' "$f"; $SUDO install -m 0755 "$f" /usr/local/bin/speedtest-cli
}
gh_fzf() {         # per-user: ~/.fzf + key bindings + completion for bash and zsh
    command -v git >/dev/null 2>&1 || return 1
    run_as_user bash -c 'd="$HOME/.fzf"; [ -d "$d/.git" ] || git clone --depth 1 https://github.com/junegunn/fzf.git "$d" || exit 1; "$d/install" --all' </dev/null
}

# ---------- Core logic ----------
declare -A STATUS HOWTO
has_any()   { local c; for c in $1; do command -v "$c" >/dev/null 2>&1 && return 0; [ -x "$TARGET_HOME/.fzf/bin/$c" ] && return 0; done; return 1; }
where_any() { local c p; for c in $1; do p="$(command -v "$c" 2>/dev/null)"; [ -z "$p" ] && [ -x "$TARGET_HOME/.fzf/bin/$c" ] && p="$TARGET_HOME/.fzf/bin/$c"; [ -n "$p" ] && { echo "$p"; return; }; done; }
try_gh()    { [ "$GITHUB" -eq 1 ] && [ -n "$1" ] && "${1#!}" >>"$LOG" 2>&1 && LAST_HOW="github"; }

process_tool() {
    local name="$1" chk="$2" apt="$3" rpm="$4" gh="$5" pk ghfirst=0 ok=1
    LAST_HOW=""
    [ -z "$rpm" ] && rpm="$apt"
    [ "${gh#!}" != "$gh" ] && ghfirst=1
    if [ "$PM" = apt ]; then pk="$apt"; else pk="$rpm"; fi
    if has_any "$chk"; then STATUS[$name]=present; HOWTO[$name]="already installed"; printf '  [skip] %-20s already installed\n' "$name"; return; fi
    [ $ghfirst -eq 1 ] && try_gh "$gh" && has_any "$chk" && ok=0
    [ $ok -ne 0 ] && [ -n "$pk" ] && [ "$pk" != "-" ] && try_pkg "$pk" && has_any "$chk" && ok=0
    [ $ok -ne 0 ] && [ $ghfirst -eq 0 ] && [ -n "$gh" ] && try_gh "$gh" && has_any "$chk" && ok=0
    if [ $ok -eq 0 ]; then STATUS[$name]=installed; HOWTO[$name]="$LAST_HOW"; printf '  %s[ OK ]%s %-20s %s\n' "$G" "$N" "$name" "$LAST_HOW"
    else STATUS[$name]=failed; HOWTO[$name]="not available"; printf '  %s[FAIL]%s %-20s see log\n' "$R" "$N" "$name"; fi
}

# ---------- Run ----------
pm_update
info "Installing prerequisites (curl, ca-certificates, tar, unzip, git)..."
for p in curl ca-certificates tar unzip git; do try_pkg "$p" || warn "prerequisite $p not installed"; done

for line in "${TOOLS[@]}"; do
    case "$line" in
        @*) HDR="${line#@}"; continue ;;
    esac
    IFS='|' read -r name chk apt rpm gh <<<"$line"
    [ -n "$ONLY" ] && case "$ONLY" in *",$name,"*) ;; *) continue ;; esac
    [ -n "${HDR:-}" ] && { info; info "${B}${HDR}${N}"; HDR=""; }
    process_tool "$name" "$chk" "$apt" "$rpm" "$gh"
done

# Debian names -> usual names (bat -> batcat, fd -> fdfind)
for pair in "bat:batcat" "fd:fdfind"; do
    want="${pair%%:*}"; have="${pair##*:}"
    if ! command -v "$want" >/dev/null 2>&1 && command -v "$have" >/dev/null 2>&1; then
        $SUDO ln -sf "$(command -v "$have")" "/usr/local/bin/$want" && info "  linked $want -> $have"
    fi
done

# ---------- Optional: ~/.bash_aliases ----------
install_aliases() {
    local dst="$TARGET_HOME/.bash_aliases" tmp="$GH_TMP/bash_aliases.new" rc
    sed -n "/^: <<'__ALIASES_END__'\$/,/^__ALIASES_END__\$/p" "$0" | sed '1d;$d' > "$tmp"
    if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then info "  [skip] $dst is up to date"
    else
        [ -f "$dst" ] && cp -p "$dst" "$dst.bak.$(date +%Y%m%d-%H%M%S)" && info "  old file backed up to $dst.bak.*"
        install -m 0644 "$tmp" "$dst" && chown "$TARGET_USER" "$dst" 2>/dev/null
        info "  ${G}[ OK ]${N} $dst written"
    fi
    for rc in "$TARGET_HOME/.bashrc" "$TARGET_HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        grep -q 'bash_aliases' "$rc" 2>/dev/null || {
            printf '\n[ -f ~/.bash_aliases ] && . ~/.bash_aliases\n' >> "$rc"
            info "  added source line to $rc"
        }
    done
}
if [ "$WITH_ALIASES" -eq 1 ]; then info; info "${B}Aliases${N}"; install_aliases; fi

# ---------- Checklist ----------
nok=0; nnew=0; nfail=0; failed=""
info; info "${B}==================== CHECKLIST ====================${N}"
for line in "${TOOLS[@]}"; do
    case "$line" in @*) HDR="${line#@}"; continue ;; esac
    IFS='|' read -r name chk apt rpm gh <<<"$line"
    [ -n "$ONLY" ] && case "$ONLY" in *",$name,"*) ;; *) continue ;; esac
    [ -n "${HDR:-}" ] && { info; info "${B}${HDR}${N}"; HDR=""; }
    case "${STATUS[$name]:-failed}" in
        present)   nok=$((nok+1));  printf '  [x] %-20s %s\n' "$name" "$(where_any "$chk")" ;;
        installed) nnew=$((nnew+1)); printf '  [x] %-20s %s  (new: %s)\n' "$name" "$(where_any "$chk")" "${HOWTO[$name]}" ;;
        *)         nfail=$((nfail+1)); failed="$failed $name"; printf '  %s[ ]%s %-20s MISSING\n' "$R" "$N" "$name" ;;
    esac
done
info; info "Already present: $nok   Installed now: $nnew   Missing: $nfail"
[ "$nfail" -gt 0 ] && { warn "missing:$failed"; warn "details: $LOG  (try again with a proxy, or see the tool's own repo)"; }
info
info "Next: reload the shell (source ~/.bashrc  or  source ~/.zshrc), fzf is picked up from ~/.fzf/bin"
[ "$nfail" -eq 0 ]; exit $?

# ---------- Embedded aliases (written by --aliases) ----------
# A no-op heredoc: bash never executes it, install_aliases() extracts it with sed.
: <<'__ALIASES_END__'
# ============================================================
#  ~/.bash_aliases - toolkit aliases (bash + zsh)
#  Every alias is guarded: a host without the tool skips it silently.
# ============================================================

# Interactive shells only
case $- in *i*) ;; *) return 0 ;; esac

# ---------- Helpers ----------
_have() { command -v "$1" >/dev/null 2>&1; }
# _ali <tool> <alias-name> '<command>'  -> define alias only if <tool> exists
_ali()  { _have "$1" || return 0; alias "$2=$3"; }

# fzf installed via git clone lives in ~/.fzf/bin; ~/.fzf.bash is sourced AFTER this
# file in .bashrc, so add it to PATH here to make the guards below see fzf
if [ -d "$HOME/.fzf/bin" ]; then
    case ":$PATH:" in *":$HOME/.fzf/bin:"*) ;; *) PATH="$PATH:$HOME/.fzf/bin" ;; esac
fi

# Debian/Ubuntu/Astra ship these under different names (batcat, fdfind)
unalias bat fd 2>/dev/null
_bat="$(command -v bat || command -v batcat)"
_fd="$(command -v fd || command -v fdfind)"
case "$_bat" in *batcat) alias bat='batcat' ;; esac
case "$_fd"  in *fdfind) alias fd='fdfind'  ;; esac

# ---------- Always available ----------
alias scat='sudo cat'                                   # read a root-only file
_ali psql pg 'sudo -u postgres psql'                    # psql as postgres user

# ---------- Navigation & files ----------
_ali eza ez   'eza -l --group-directories-first'        # ls -l with colors, dirs first
_ali eza ezs  'sudo eza -l --group-directories-first'   # same, as root (restricted dirs)
_ali eza ezl  'eza -la --git'                           # all files + git status
_ali eza ezt  'eza -T -L2'                              # tree, 2 levels
if _have zoxide; then                                   # z <part-of-path>, zi = interactive pick
    if [ -n "$ZSH_VERSION" ]; then eval "$(zoxide init zsh)"; else eval "$(zoxide init bash)"; fi
fi
[ -n "$_bat" ] && alias bp="$_bat -p"                   # cat with syntax highlight, no decorations
_ali delta dl 'delta'                                   # nice diff of two files: dl a.conf b.conf
_ali fastfetch ff 'fastfetch'                           # system summary
if _have yazi; then                                     # file manager; shell cd's to where you quit
    y() {
        local tmp cwd
        tmp="$(mktemp -t yazi-cwd.XXXXXX)"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
fi

# ---------- Search ----------
_ali rg rgi 'rg -i'                                     # case-insensitive: rgi error /var/log
_ali rg rgl 'rg -l'                                     # only list matching files
[ -n "$_fd" ] && {
    alias fdf="$_fd -t f"                               # find files:       fdf '\.yml$'
    alias fdd="$_fd -t d"                               # find directories: fdd postgres
}

# ---------- System management & logs ----------
_ali systemd-manager-tui smt 'sudo systemd-manager-tui' # TUI for system units
_ali lnav lgv 'sudo lnav /var/log'                      # browse all logs
if _have lnav; then
    alias jnl='sudo journalctl -o short-iso -n 5000 | lnav'   # last 5000 journal lines in lnav
fi
_ali journalctl jerr 'sudo journalctl -p err -b -o short-iso' # errors since last boot
_ali lazyjournal lj 'sudo lazyjournal'                  # TUI for journald/files/docker logs

# ---------- Process, CPU & memory ----------
_ali lsof   lsp 'sudo lsof -iTCP -sTCP:LISTEN -P -n'    # who listens on which TCP port
_ali ss     lss 'sudo ss -tulpn'                        # listening TCP+UDP sockets with process
_ali vmstat vm  'vmstat -S M 1'                         # memory/CPU/IO every second, in MB
_ali mpstat mp  'mpstat -P ALL 1'                       # per-core CPU every second

# ---------- Networking ----------
_ali tcpdump tcpd 'sudo tcpdump -nni any'               # tcpd port 443 | tcpd host 10.0.0.5
if _have tshark; then
    tsp() { sudo tshark -n -i any -f "port ${1:?usage: tsp <port> [tshark args]}" "${@:2}"; }
fi
_ali mtr  mt   'mtr -rwbc 50'                           # route report: mt 8.8.8.8
_ali iftop ift 'sudo iftop -nNP'                        # bandwidth per connection, with ports
_ali dig  digs 'dig +short'                             # digs example.com
_ali dig  diga 'dig +noall +answer'                     # answer lines only
_ali xh   xv   'xh -v'                                  # HTTP request, show request + response
_ali nc   ncz  'nc -zv -w 3'                            # port check (3s timeout): ncz host 443
_ali speedtest-cli speed 'speedtest-cli --simple'       # ping / down / up

# ---------- Storage & disk I/O ----------
_ali duf dfl 'duf --only local'                         # disks without tmpfs/network noise
if _have ncdu; then
    alias ncx='ncdu -x'                                 # usage of current dir, one filesystem
    alias ncr='sudo ncdu -x /'                          # what eats the root filesystem
fi
_iot="$(command -v iotop-c || command -v iotop)"
[ -n "$_iot" ] && alias iot="sudo $_iot -o"             # only processes doing I/O right now
_ali smartctl smh 'sudo smartctl -H'                    # disk health:  smh /dev/sda
_ali smartctl sma 'sudo smartctl -a'                    # full SMART report

# ---------- fzf: interactive fuzzy selection ----------
# Built-in keys (from ~/.fzf.bash / ~/.fzf.zsh): Ctrl-T files, Ctrl-R history, Alt-C cd
if _have fzf; then
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
    if [ -n "$_fd" ]; then
        export FZF_DEFAULT_COMMAND="$_fd --type f --hidden --exclude .git"
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND="$_fd --type d --hidden --exclude .git"
        _fzf_dircmd="$FZF_ALT_C_COMMAND"
    else
        _fzf_dircmd="find . -type d -not -path '*/.git/*' 2>/dev/null"
    fi
    if [ -n "$_bat" ]; then
        _fzf_prev="$_bat --style=numbers --color=always --line-range :200 {}"
    else
        _fzf_prev='head -200 {}'
    fi

    fo() {      # fo [dir]  - pick a file (with preview), open in $EDITOR
        local base="${1:-.}" f
        f="$(cd "$base" && fzf --preview "$_fzf_prev")" || return
        ${EDITOR:-vim} "$base/$f"
    }
    fcd() {     # fcd [dir] - pick a directory and cd into it
        local base="${1:-.}" d
        d="$(cd "$base" && eval "$_fzf_dircmd" | fzf)" || return
        cd "$base/$d" || return
    }
    fkill() {   # fkill [signal] - pick process(es), TAB = multi-select, default SIGTERM
        local pids
        pids="$(ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | fzf -m --header-lines=1 | awk '{print $1}')" || return
        [ -n "$pids" ] && echo "$pids" | xargs sudo kill -"${1:-15}"
    }
    fjl() {     # fjl - pick a systemd service and follow its journal
        local u
        u="$(systemctl list-units --type=service --all --no-legend --plain | awk '{print $1}' \
            | fzf --preview 'systemctl status --no-pager -n 15 {}')" || return
        sudo journalctl -u "$u" -n 200 -f
    }
    fssh() {    # fssh - pick a host from ~/.ssh/config and connect
        local h
        h="$(awk '$1=="Host"{for(i=2;i<=NF;i++) if($i !~ /[*?!]/) print $i}' ~/.ssh/config 2>/dev/null | fzf)" || return
        ssh "$h"
    }
fi

unset _bat _fd _iot
# ---------- END toolkit aliases ----------
__ALIASES_END__
