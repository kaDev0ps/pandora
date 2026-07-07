#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
NC='\033[0m' # No Color

# IP address – first non‑loopback IPv4
LOCAL_IP=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '^127\.' | head -1)
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
LOCAL_IP="${LOCAL_IP:-N/A}"

# Hostname
HOSTNAME=$(hostname)

# OS pretty name
OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')
OS="${OS:-Unknown}"

# Current user
USER_NAME=$(whoami)
if [ "$USER_NAME" = "root" ]; then
    USER_COLOR="${RED}${USER_NAME}${NC}"
else
    USER_COLOR="$USER_NAME"
fi

# Load average (1, 5, 15 min)
LOADAVG=$(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || echo "N/A")

# Uptime
UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //' || echo "N/A")

# CPU count
CPU_COUNT=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "N/A")

# Memory – prefer "available" (column 7) otherwise "free" (column 4)
mem_info=$(free -m 2>/dev/null | awk '/Mem:/{print $2,$4,$7}')
if [ -n "$mem_info" ]; then
    RAM_TOTAL=$(echo "$mem_info" | awk '{print $1}')
    RAM_FREE_FALLBACK=$(echo "$mem_info" | awk '{print $2}')
    RAM_AVAILABLE=$(echo "$mem_info" | awk '{print $3}')
    # If available column exists and is non‑empty, use it, else fallback to free
    if [ -n "$RAM_AVAILABLE" ] && [ "$RAM_AVAILABLE" != "" ]; then
        RAM_FREE=$RAM_AVAILABLE
    else
        RAM_FREE=$RAM_FREE_FALLBACK
    fi
    RAM_FREE_PCT=$(awk -v total="$RAM_TOTAL" -v free="$RAM_FREE" 'BEGIN{printf "%.1f", (free*100/total)}')
else
    RAM_TOTAL="N/A"
    RAM_FREE="N/A"
    RAM_FREE_PCT="N/A"
fi

# Disk space for /
disk_info=$(df -B1 --output=size,avail / 2>/dev/null | awk 'NR==2 {print $1, $2}')
if [ -n "$disk_info" ]; then
    DISK_TOTAL_BYTES=$(echo "$disk_info" | awk '{print $1}')
    DISK_FREE_BYTES=$(echo "$disk_info" | awk '{print $2}')
    DISK_TOTAL_HUMAN=$(numfmt --to=iec --suffix=B "$DISK_TOTAL_BYTES" 2>/dev/null || echo "$((DISK_TOTAL_BYTES/1024/1024/1024))G")
    DISK_FREE_HUMAN=$(numfmt --to=iec --suffix=B "$DISK_FREE_BYTES" 2>/dev/null || echo "$((DISK_FREE_BYTES/1024/1024/1024))G")
    DISK_FREE_PCT=$(awk -v total="$DISK_TOTAL_BYTES" -v free="$DISK_FREE_BYTES" 'BEGIN{printf "%.1f", (free*100/total)}')
else
    DISK_TOTAL_HUMAN="N/A"
    DISK_FREE_HUMAN="N/A"
    DISK_FREE_PCT="N/A"
fi

# ─────────────────────────────────────────
#  Display
# ─────────────────────────────────────────
echo ""
echo "-----------------------------------------"
echo "IP                    : ${LOCAL_IP}"
echo "Hostname              : ${HOSTNAME}"
echo "OS                    : ${OS}"
echo -e "USER                  : ${USER_COLOR}"
echo "Load Average          : ${LOADAVG}"
echo "Uptime                : ${UPTIME}"
echo "-----------------------------------------"
echo "CPU                   : ${CPU_COUNT} CPU(s)"
echo "RAM                   : ${RAM_TOTAL} MB total, ${RAM_FREE} MB available (${RAM_FREE_PCT}%)"
echo "HDD (/)               : ${DISK_TOTAL_HUMAN} total, ${DISK_FREE_HUMAN} free (${DISK_FREE_PCT}%)"
echo "-----------------------------------------"
echo ""
