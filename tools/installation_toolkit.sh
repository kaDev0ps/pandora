#!/usr/bin/env bash
# ============================================================
#  install_fzf.sh - idempotent fzf installer (Debian-family, ALT, RHEL-like)
#  Method 1: git clone ~/.fzf + ~/.fzf/install --all  (latest version, per-user)
#  Method 2: fallback to the distro package (older version, needs root/sudo)
#  Usage:  ./install_fzf.sh            (or: source it and call install_fzf)
# ============================================================
FZF_DIR="${FZF_DIR:-$HOME/.fzf}"

_fzf_bin() {
    if command -v fzf >/dev/null 2>&1; then command -v fzf
    elif [ -x "$FZF_DIR/bin/fzf" ]; then echo "$FZF_DIR/bin/fzf"
    fi
}

_fzf_pkg_install() {
    local SUDO=""
    [ "$(id -u)" -ne 0 ] && SUDO="sudo"
    if   command -v apt-get >/dev/null 2>&1; then $SUDO apt-get install -y fzf      # Debian, Ubuntu, Astra, ALT (apt-rpm)
    elif command -v dnf     >/dev/null 2>&1; then $SUDO dnf install -y fzf
    elif command -v yum     >/dev/null 2>&1; then $SUDO yum install -y fzf
    else return 1
    fi
}

install_fzf() {
    local bin
    bin="$(_fzf_bin)"
    if [ -n "$bin" ]; then
        echo "[skip] fzf already installed: $("$bin" --version 2>/dev/null)"
        return 0
    fi

    echo "[....] installing fzf via git clone into $FZF_DIR"
    if command -v git >/dev/null 2>&1; then
        [ -d "$FZF_DIR/.git" ] || git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
        # --all = completion + key bindings + update ~/.bashrc and ~/.zshrc, no questions
        [ -x "$FZF_DIR/install" ] && "$FZF_DIR/install" --all
    fi

    if [ -z "$(_fzf_bin)" ]; then
        echo "[warn] git method failed (no git or no access to github.com), trying package manager"
        _fzf_pkg_install
    fi

    bin="$(_fzf_bin)"
    if [ -n "$bin" ]; then
        echo "[ OK ] fzf installed: $("$bin" --version 2>/dev/null)"
        echo "       reload the shell: source ~/.bashrc   (zsh: source ~/.zshrc)"
        return 0
    fi
    echo "[FAIL] fzf was not installed"
    return 1
}

# Checklist line for the end of your universal installer
fzf_checklist() {
    local bin; bin="$(_fzf_bin)"
    if [ -n "$bin" ]; then printf '  [x] %-10s %s\n' fzf "$("$bin" --version 2>/dev/null | cut -d' ' -f1)"
    else printf '  [ ] %-10s %s\n' fzf "MISSING"
    fi
}

# Run directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_fzf; rc=$?
    echo; echo "Checklist:"; fzf_checklist
    exit $rc
fi
