#!/bin/bash

# Установим vim редактором по умолчанию для visudo
export EDITOR=vim

# Пользователи и их данные (логины, хэши паролей, SSH-ключи)
USER1=netrika_ka
PASSWORD_HASH1='$6$XbcQtpB9Zo3SioF8$Ay.zAYsryFKcRO5PAHKn9V.yh8UoWoUowWCrr/ZEQhrFiYQrCDjfrR81vH9xJMcuPnVqMPPBku5nIl3uRNUAc.'
SSH_KEY1='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIb8KYTeJGHIcZhBS3jnQRqXbnIF+2BMHz379myWyW4I a.karmash@n3med.ru'

USER2=ansible
PASSWORD_HASH2='$6$tvdfLIWJvMTAd7Is$ERcaC0cuf8h.23yPEEMOmT8FyLbVhGf3cAQb79Nx1k29EtpHpX2Z6sGa6as1AX2csO.lQ.lKyQtHE/f31x31R0'
SSH_KEY2='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzVowOUyJqcubL0MylzupIy6Lr1bDy+rlSaNhmWRC+n ansible@szpv-rundeck-app-01'

USER3=netrika_na
PASSWORD_HASH3='$6$hbZIjkt5FXEMhDCM$WjKpfof8G/ZGMgh.JyqS2Q9yewsM4PdmOzfkIhWuLf.xRDjieDxIRARtwW3XkzVH0Cm5Hug2.Ej9C.Q/evTAQ/'
SSH_KEY3='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH9khHXvA3mk9icB+dwClC44HAloni84XHKvoL/XuKXj n.anisimov-20230206'

USER4=netrika_ms
PASSWORD_HASH4='$6$2OP5C0V.2MCMz1MO$NqU8593AlfcAsGhXu6sQR.3MOiz7qbkrDYv9jKs2SCM4I.eoGOi/mDcEMGCKC7F2HTMLpPig9rbCCH80ioyTM/'
SSH_KEY4='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCTx70b7dbdrG+OiH0eLzoC53A3zHT9hJoizraIB3RaRNVMwBEv2NmwAfFWQgQH/j86xJ7lh+WPp/FopReFUQETwANfmB6Cbi1E7+h3jfLzgXIzgCStjKxuTyrimCT9Uvt7W9+a15+Qz4U+IwlgGMip8aoUtrZ5XSwsbzyNYiX0Eod1Bagb6tt6VF/ZSNINjyHPsHJUUzNZh3PwGcXQRBaJiQ7CU69BJ5vW2vOfr0Cvrqwf5eB9VChh3j05JkHAYpauZwpLz1Plg8pKTou5Il2Vj4zRwXgf3Ag5ImbT+jLatLH5umMhZ9M0fJgfff5EROkQTKxKKcvXIWEw6B/45vsxFWcIyWbrQfCbzsOYGSl3HWAO0jBjd2g4lJhOlgdE8QUnWz01S5+UltHF6Vg+KiI6xlStFfV7n3jdFtUsgBTpcW6toS4XCJVjJKPW1zfAgDL0zkRg+KQxe9gAM/Kl+OA3hyTVXS8piwQhFcBQLtcD7dqfJ6hHqdp/CbTYh6lcXjH+kli+lFAnqhU0gqRJ6ejiWnIVu0cFtwULqWErP+MDWY37saU5h4XJSnrkwm7U9DogONsZs8346pYNkz0iaAW6YSt4VUT5pdyt/H+ZQGnlwcVWlMI3cidyOAicbs45s+cbarwnVRL4qjcF2ruq6a6HPcRqyXrCC2dzdiOMGBfFkw== s.mironenko@n3med.ru'

USER5=netrika_sr
PASSWORD_HASH5='$6$fluvaCW6Jl.sQBW2$aURvL11oVV/9xlRNiITSxjpKB0ZlhxELSGRcvbLXoqY1gYAszb3cAh5jhhrvFjNbaTe3f5dGXbWhvdzRAt9P2/'
SSH_KEY5='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC528lPgMSZwl3B2pSrIU2DNSz0Hzyte3fZQ8tDfTdOpQo5Qs/R2weWgoEHFTYJMMd60exoh35uPJ9kUqGWKCecLmce+q/xGNTi2GstP0jmxWxNyqWm+do9BNY1wyKbhXY4vUURJw3kk27Pu/FsAlM9ibeX+9fxCU9dXQ7Tqe5oKnkaiGSf43ti/sbA88n8/5HPDbW2ihQQxJkHKryGNeYP+WOZSimt13aHQ2kOG8LtZudLDgfpnKhRab1ilhlLdlHUa2kaZ54iH/SOOLdg+424SJozH/yPy2jMD4VUa/eqIXRoyjw1aXaEfdV3WzkFn5E0QfwRYsr22Xz+ZMBMWz2VJgal4yCuEBPYfYR2p3FlDxfQqdCgF/carE5JUaxtLcI10e9W0t08zMKW/BBAp1/cA/tvuVpsfkOpBZ2TND523eIRfwfuumJZA/bxGi19C0owzxqIjMHBKnLBP+MWKk9CvXnEzsbMxXhbNnEvKtP+4rWn1cWVAz0PPEw9L/M6/jc='

create_or_update_user() {
    local USERNAME=$1
    local PASSWORD_HASH=$2
    local SSH_KEY=$3

    # Определяем ОС с учетом регистра: ищем 'alt' или 'ALT' в ID/DISTRIB_ID
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        DISTRO_ID="${DISTRIB_ID:-}"
        # Приводим к нижнему регистру для сравнения
        OS_NAME_LC=$(echo "$OS_NAME" | tr '[:upper:]' '[:lower:]')
        DISTRO_ID_LC=$(echo "$DISTRO_ID" | tr '[:upper:]' '[:lower:]')
        if [ -z "$DISTRO_ID_LC" ] && command -v lsb_release >/dev/null 2>&1; then
            DISTRO_ID_LC=$(lsb_release -i -s | tr '[:upper:]' '[:lower:]')
        fi

        if [[ "$OS_NAME_LC" =~ alt ]] || [[ "$DISTRO_ID_LC" =~ alt ]]; then
            OS_TYPE=alt
        else
            OS_TYPE=astra
        fi
        echo "Detected OS_TYPE: $OS_TYPE"
    else
        echo "Cannot detect OS"
        exit 1
    fi

    # Выбор группы для sudo (wheel для Alt, sudo для Astra)
    if [ "$OS_TYPE" = "alt" ]; then
        SUDO_GROUP=wheel
    else
        SUDO_GROUP=sudo
    fi

    # Проверка и создание пользователя
    if id "$USERNAME" &>/dev/null; then
        echo "User $USERNAME exists, updating info..."
        sudo usermod -p "$PASSWORD_HASH" -s /bin/bash "$USERNAME"
    else
        echo "Creating user $USERNAME..."
        sudo useradd -m -d /home/"$USERNAME" -s /bin/bash -p "$PASSWORD_HASH" -G "$SUDO_GROUP" "$USERNAME"
    fi

    # Настройка .ssh
    if [ ! -d /home/"$USERNAME"/.ssh ]; then
        sudo mkdir -p /home/"$USERNAME"/.ssh
        sudo chown "$USERNAME" /home/"$USERNAME"/.ssh
        sudo chmod 700 /home/"$USERNAME"/.ssh
    fi

    # Добавление ключа, если ещё нет
    if [ ! -f /home/"$USERNAME"/.ssh/authorized_keys ] || ! sudo grep -qF "$SSH_KEY" /home/"$USERNAME"/.ssh/authorized_keys; then
        echo "$SSH_KEY" | sudo tee -a /home/"$USERNAME"/.ssh/authorized_keys > /dev/null
        sudo chmod 600 /home/"$USERNAME"/.ssh/authorized_keys
        sudo chown "$USERNAME" /home/"$USERNAME"/.ssh/authorized_keys
    fi

    # Добавление в sudoers через отдельный файл /etc/sudoers.d/$USERNAME
    SUDOERS_ENTRY="$USERNAME ALL=(ALL) NOPASSWD:ALL"
    SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

    if [ ! -f "$SUDOERS_FILE" ] || ! sudo grep -qF "$SUDOERS_ENTRY" "$SUDOERS_FILE"; then
        echo "$SUDOERS_ENTRY" | sudo tee "$SUDOERS_FILE" > /dev/null
        sudo chmod 440 "$SUDOERS_FILE"
    fi
}

# Добавление всех пользователей
create_or_update_user "$USER1" "$PASSWORD_HASH1" "$SSH_KEY1"
create_or_update_user "$USER2" "$PASSWORD_HASH2" "$SSH_KEY2"
create_or_update_user "$USER3" "$PASSWORD_HASH3" "$SSH_KEY3"
create_or_update_user "$USER4" "$PASSWORD_HASH4" "$SSH_KEY4"
create_or_update_user "$USER5" "$PASSWORD_HASH5" "$SSH_KEY5"

echo "SUCCESS"
