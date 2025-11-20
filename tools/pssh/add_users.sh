#!/bin/bash

# Detect if OS is Alt Linux
is_alt_linux() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "altlinux" ]]; then
            return 0
        fi
    fi
    return 1
}

# User creds
USER1=netrika_ka
PASSWORD_HASH1='!!!!!!!!!!!!!!!!SHA256!!!!!!!!!!!!!'
SSH_KEY1='!!!!!!!!!!!!!!!!!!!!!!SSH KEY!!!!!!!!!!!!'

USER2=netrika_sd
PASSWORD_HASH2='!!!!!!!!!!!!!!!!SHA256!!!!!!!!!!!!!'
SSH_KEY2='!!!!!!!!!!!!!!!!!!!!!!SSH KEY!!!!!!!!!!!!'

USER3=netrika_na
PASSWORD_HASH3='!!!!!!!!!!!!!!!!SHA256!!!!!!!!!!!!!'
SSH_KEY3='!!!!!!!!!!!!!!!!!!!!!!SSH KEY!!!!!!!!!!!!'

USER4=netrika_ms
PASSWORD_HASH4='!!!!!!!!!!!!!!!!SHA256!!!!!!!!!!!!!'
SSH_KEY4='!!!!!!!!!!!!!!!!!!!!!!SSH KEY!!!!!!!!!!!!'

USER5=netrika_sr
PASSWORD_HASH5='!!!!!!!!!!!!!!!!SHA256!!!!!!!!!!!!!'
SSH_KEY5='!!!!!!!!!!!!!!!!!!!!!!SSH KEY!!!!!!!!!!!!'

# Ensure sudoers.d directory exists before processing users
ensure_sudoers_d_dir() {
    if [ ! -d /etc/sudoers.d ]; then
        sudo mkdir -p /etc/sudoers.d
        sudo chmod 755 /etc/sudoers.d
    fi
}

create_or_update_user() {
    local USERNAME=$1
    local PASSWORD_HASH=$2
    local SSH_KEY=$3

    # Create user if not exists
    if ! id "$USERNAME" &>/dev/null; then
        sudo useradd -m -s /bin/bash "$USERNAME"
    fi

    # Set password hash
    echo "$USERNAME:$PASSWORD_HASH" | sudo chpasswd -e

    # Create .ssh directory and set permissions
    if [ ! -d /home/"$USERNAME"/.ssh ]; then
        sudo mkdir -p /home/"$USERNAME"/.ssh
        sudo chown "$USERNAME":"$(id -gn $USERNAME)" /home/"$USERNAME"/.ssh
        sudo chmod 700 /home/"$USERNAME"/.ssh
    fi

    # Add SSH key to authorized_keys
    if [ ! -f /home/"$USERNAME"/.ssh/authorized_keys ] || ! sudo grep -qF "$SSH_KEY" /home/"$USERNAME"/.ssh/authorized_keys; then
        echo "$SSH_KEY" | sudo tee -a /home/"$USERNAME"/.ssh/authorized_keys > /dev/null
        sudo chmod 600 /home/"$USERNAME"/.ssh/authorized_keys
        sudo chown "$USERNAME":"$(id -gn $USERNAME)" /home/"$USERNAME"/.ssh/authorized_keys
    fi

    # For Astra Linux, run pdpl-user to set integrity level only if NOT Alt Linux
    if ! is_alt_linux; then
        sudo pdpl-user -i 63 "$USERNAME"
    else
        # On Alt Linux, add user to wheel group
        sudo usermod -aG wheel "$USERNAME"
    fi

    # Sudoers setup
    SUDOERS_ENTRY="$USERNAME ALL=(ALL) NOPASSWD:ALL"
    SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

    # Remove old entry if exists
    if [ -f "$SUDOERS_FILE" ]; then
        sudo sed -i "\|^$SUDOERS_ENTRY\$|d" "$SUDOERS_FILE"
    fi

    # Add new entry
    echo "$SUDOERS_ENTRY" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"

    # Remove matching line from /etc/sudoers if sudoers.d file exists and is non-empty
    if [ -f "$SUDOERS_FILE" ] && sudo test -s "$SUDOERS_FILE"; then
        if sudo grep -qE "^$USERNAME\s+ALL=\(ALL\).*NOPASSWD:ALL$" /etc/sudoers; then
            sudo sed -i "/^$USERNAME\s\+ALL=(ALL).*NOPASSWD:ALL$/d" /etc/sudoers
        else
            echo "No matching line for $USERNAME found in /etc/sudoers; skipping removal."
        fi
    fi
}

# Ensure the sudoers.d directory exists first
ensure_sudoers_d_dir

# Then process users
create_or_update_user "$USER1" "$PASSWORD_HASH1" "$SSH_KEY1"
create_or_update_user "$USER2" "$PASSWORD_HASH2" "$SSH_KEY2"
create_or_update_user "$USER3" "$PASSWORD_HASH3" "$SSH_KEY3"
create_or_update_user "$USER4" "$PASSWORD_HASH4" "$SSH_KEY4"
create_or_update_user "$USER5" "$PASSWORD_HASH5" "$SSH_KEY5"

echo "SUCCESS"

# Show sudoers.d directory listing
echo -e "\nContents of /etc/sudoers.d/:"
sudo ls -l /etc/sudoers.d

# Show last 10 lines of /etc/sudoers
echo -e "\nLast 10 lines of /etc/sudoers:"
sudo tail -n 10 /etc/sudoers
