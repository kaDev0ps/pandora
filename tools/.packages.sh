#!/bin/bash -xve
set -xve

# Обновляем список пакетов
sudo apt-get update

# Определяем дистрибутив
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro=$ID
else
    distro=""
fi

# Общие пакеты для всех дистрибутивов
COMMON_PACKAGES=(htop btop wget nmap mtr tree ncdu ripgrep ccze ranger lsof iotop icdiff grc )

# Пакеты для Astra Linux
ASTRA_PACKAGES=(locate)

# Пакеты для Alt Linux
ALT_PACKAGES=(mlocate)

# Функция для установки пакетов с игнорированием ошибок
install_packages() {
    packages=("$@")
    for pkg in "${packages[@]}"; do
        if sudo apt-get install -y "$pkg"; then
            echo "Пакет $pkg установлен успешно."
        else
            echo "Ошибка установки пакета $pkg, пропускаем и продолжаем."
        fi
    done
}

# Установка общих пакетов
install_packages "${COMMON_PACKAGES[@]}"

# Установка специфичных пакетов в зависимости от дистрибутива
if [[ "$distro" == "astra" ]]; then
    install_packages "${ASTRA_PACKAGES[@]}"
    sudo updatedb
elif [[ "$distro" == "altlinux" || "$distro" == "alt" ]]; then
    install_packages "${ALT_PACKAGES[@]}"
    sudo updatedb
else
    echo "Дистрибутив не распознан. Установка специфичных пакетов не выполнена."
    exit 1
fi

# Устанавливаем zsh из вашего скрипта
mkdir -p "$HOME/tools" && wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.install_zsh -O "$HOME/tools/.install_zsh" && chmod +x "$HOME/tools/.install_zsh" && "$HOME/tools/.install_zsh"
# Connect Aliash
wget https://raw.githubusercontent.com/kaDev0ps/pandora/main/tools/.bash_alias -O ~/.bash_aliases && grep -qxF 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' ~/.bashrc || echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> ~/.bashrc && grep -qxF 'if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi' ~/.zshrc || echo 'if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi' >> ~/.zshrc && exec zsh
