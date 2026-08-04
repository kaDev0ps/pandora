#!/bin/bash
# Server info + problem-hunting diagnostics
# Цвета
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# IP первого сетевого интерфейса
LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '^127\.' | head -n 1)
HOSTNAME=$(hostname)
OS=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
USER_NAME=$(whoami)
if [ "$USER_NAME" = "root" ]; then
    USER_NAME="${RED}${USER_NAME}${NC}"
fi

LOADAVG=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
UPTIME=$(uptime -p)
CPU_COUNT=$(nproc)

RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_FREE=$(free -m | awk '/Mem:/ {print $7}')
RAM_FREE_PCT=$(( RAM_FREE * 100 / RAM_TOTAL ))

DISK_TOTAL_HUMAN=$(df -h / | awk 'NR==2 {print $2}')
DISK_FREE_HUMAN=$(df -h / | awk 'NR==2 {print $4}')
DISK_TOTAL=$(df -k / | awk 'NR==2 {print $2}')
DISK_FREE=$(df -k / | awk 'NR==2 {print $4}')
DISK_FREE_PCT=$(( DISK_FREE * 100 / DISK_TOTAL ))

echo ""
echo "-----------------------------------------"
echo "IP                    : ${LOCAL_IP:-N/A}"
echo "Hostname              : $HOSTNAME"
echo "OS                    : $OS"
echo -e "USER                  : $USER_NAME"
echo "Load Average          : $LOADAVG"
echo "Uptime                : $UPTIME"
echo "-----------------------------------------"
echo "CPU                   : ${CPU_COUNT} CPU"
echo "RAM                   : ${RAM_TOTAL} MB, ${RAM_FREE} MB (${RAM_FREE_PCT}%) free"
echo "HDD (/)               : ${DISK_TOTAL_HUMAN}, ${DISK_FREE_HUMAN} (${DISK_FREE_PCT}%) free"
echo "-----------------------------------------"

# ---- I/O wait (flags a disk bottleneck) ----
vmstat_out=$(vmstat 1 2 | tail -n 1)
IO_WAIT=$(echo "$vmstat_out" | awk '{print $16}')
IO_BLOCKED=$(echo "$vmstat_out" | awk '{print $1}')
IO_LINE="CPU IO-Wait: ${IO_WAIT}% | Tasks Blocked on I/O: ${IO_BLOCKED}"
# highlight if IO wait or blocked tasks look high
if [ "$IO_WAIT" -ge 20 ] 2>/dev/null || [ "$IO_BLOCKED" -ge 1 ] 2>/dev/null; then
    echo -e "${YELLOW}${IO_LINE}${NC}"
else
    echo "$IO_LINE"
fi

# ---- Network traffic (1s sample) ----
net_interface=$(ip route | grep default | awk '{print $5}' | head -n 1)
[ -z "$net_interface" ] && net_interface=$(awk 'NR>2 {print $1}' /proc/net/dev | tr -d ':' | grep -v 'lo' | head -n 1)

if [ -n "$net_interface" ]; then
    stat1=$(grep "$net_interface" /proc/net/dev | awk '{print $2" "$10}')
    sleep 1
    stat2=$(grep "$net_interface" /proc/net/dev | awk '{print $2" "$10}')
    rx1=$(echo "$stat1" | awk '{print $1}'); tx1=$(echo "$stat1" | awk '{print $2}')
    rx2=$(echo "$stat2" | awk '{print $1}'); tx2=$(echo "$stat2" | awk '{print $2}')
    rx_speed=$(echo "$rx1 $rx2" | awk '{printf "%.2f", ($2-$1)/1024/1024}')
    tx_speed=$(echo "$tx1 $tx2" | awk '{printf "%.2f", ($2-$1)/1024/1024}')
    echo "Network [$net_interface]  : RX: $rx_speed MB/s | TX: $tx_speed MB/s"
fi
echo "-----------------------------------------"

# ---- Top services/containers by summed CPU ----
echo "TOP SERVICES/CONTAINERS BY CPU"

tmp_file=$(mktemp)

has_docker=false
command -v docker &> /dev/null && has_docker=true

ps -eo pid,%cpu,comm --no-headers | while read -r pid cpu comm; do
    [[ -z "$pid" || -z "$cpu" ]] && continue
    # Skip the ps command itself and this script's own helper processes —
    # a freshly-started ps/grep/awk shows a fake near-100% CPU spike
    # (its own cpu-time divided by its own near-zero elapsed lifetime)
    case "$comm" in
        ps|grep|awk|sed|cat|head|tr) continue ;;
    esac
    [[ "$pid" == "$$" ]] && continue

    source_origin=""
    cgroup_file="/proc/$pid/cgroup"

    if [ -r "$cgroup_file" ]; then
        cgroup_content=$(cat "$cgroup_file" 2>/dev/null)

        # Docker container?
        container_id=$(grep -oE 'docker-[a-f0-9]{64}' <<< "$cgroup_content" | head -n 1 | sed 's/docker-//')
        [ -z "$container_id" ] && container_id=$(grep -oE '/docker/[a-f0-9]{64}' <<< "$cgroup_content" | head -n 1 | awk -F'/' '{print $3}')

        if [ -n "$container_id" ] && $has_docker; then
            container_name=$(docker ps --filter "id=$container_id" --format "{{.Names}}" 2>/dev/null)
            [ -n "$container_name" ] && source_origin="Docker: $container_name"
        fi

        # Systemd unit — parsed straight from the cgroup path, no subprocess
        if [ -z "$source_origin" ]; then
            unit=$(grep -oE '[a-zA-Z0-9_.@:-]+\.(service|scope)' <<< "$cgroup_content" | head -n 1)
            [ -n "$unit" ] && source_origin="Service: $unit"
        fi
    fi

    # Real fallback: the actual process name, never a vague label
    [ -z "$source_origin" ] && source_origin="Proc: ${comm:-unknown}"

    echo "$cpu|$source_origin" >> "$tmp_file"
done

printf "%-9s %-40s %s\n" "CPU SUM%" "SERVICE / CONTAINER" "PROCS"

awk -F'|' '
{
    cpu_sum[$2] += $1;
    proc_cnt[$2]++;
}
END {
    for (service in cpu_sum) {
        printf "%.2f|%-40s|%d\n", cpu_sum[service], service, proc_cnt[service]
    }
}' "$tmp_file" | sort -rn -t'|' -k1 | head -n 5 | while IFS='|' read -r sum_cpu svc_name p_count; do
    printf "%-9s %-40s %s\n" "${sum_cpu}%" "$svc_name" "$p_count"
done

rm -f "$tmp_file"
echo "-----------------------------------------"
echo ""
