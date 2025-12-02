#!/bin/bash

# Цвета
RED='\033[0;31m'
NC='\033[0m' # No Color

# IP первого сетевого интерфейса
LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '^127\.' | head -n 1)

# Имя сервера
HOSTNAME=$(hostname)

# ОС
OS=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

# Пользователь
USER_NAME=$(whoami)

# Root красным
if [ "$USER_NAME" = "root" ]; then
    USER_NAME="${RED}${USER_NAME}${NC}"
fi

# Load average
LOADAVG=$(awk '{print $1" "$2" "$3}' /proc/loadavg)

# Uptime
UPTIME=$(uptime -p)

# Количество CPU
CPU_COUNT=$(nproc)

# RAM: всего и свободно (в мегабайтах)
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_FREE=$(free -m | awk '/Mem:/ {print $7}')
RAM_FREE_PCT=$(( RAM_FREE * 100 / RAM_TOTAL ))

# HDD: для корневого раздела /
DISK_TOTAL_HUMAN=$(df -h / | awk 'NR==2 {print $2}')
DISK_FREE_HUMAN=$(df -h / | awk 'NR==2 {print $4}')

# Используем df без форматирования для процентов
DISK_TOTAL=$(df -k / | awk 'NR==2 {print $2}')
DISK_FREE=$(df -k / | awk 'NR==2 {print $4}')
DISK_FREE_PCT=$(( DISK_FREE * 100 / DISK_TOTAL ))

echo ""
echo "-----------------------------------------"
echo "IP                    : ${LOCAL_IP:-N/A}"
echo "Hostname              : $HOSTNAME"
echo "OS                    : $OS"
echo -e "USER                  : $USER_NAME"
echo "Load Average          : $LOADAVG"
echo "Uptime                : $UPTIME"
echo "-----------------------------------------"
echo "CPU                   : ${CPU_COUNT} CPU"
echo "RAM                   : ${RAM_TOTAL} MB, ${RAM_FREE} MB (${RAM_FREE_PCT}%) free"
echo "HDD (/)               : ${DISK_TOTAL_HUMAN}, ${DISK_FREE_HUMAN} (${DISK_FREE_PCT}%) free"
echo "-----------------------------------------"
echo ""
