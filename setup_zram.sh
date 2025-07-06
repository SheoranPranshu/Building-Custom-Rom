#!/usr/bin/env bash

#
# Usage: sudo ./zram-setup.sh [-p percent] [-a algo] [-r priority] [-h]
#

set -eo pipefail

# --- Defaults (override with flags) ---
ZRAM_PERCENT=69
ZRAM_ALGO=zstd
ZRAM_PRIORITY=100

# --- Colors & Icons ---
C_BLUE="\033[1;34m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_NC="\033[0m"

ICON_SETUP="⚙️"
ICON_OK="✓"
ICON_FAIL="✗"
ICON_INFO="ℹ️"
ICON_ROCKET="🚀"

# --- Usage message ---
usage(){
  cat <<EOF
${ICON_INFO} Usage: sudo $0 [options]

  -p PERCENT   ZRAM size as % of RAM (default: ${ZRAM_PERCENT})
  -a ALGO      Compression algo (default: ${ZRAM_ALGO})
  -r PRIORITY  zram priority (default: ${ZRAM_PRIORITY})
  -h           Show this help and exit
EOF
}

# --- Parse flags ---
while getopts "p:a:r:h" opt; do
  case $opt in
    p) ZRAM_PERCENT=$OPTARG ;;
    a) ZRAM_ALGO=$OPTARG   ;;
    r) ZRAM_PRIORITY=$OPTARG ;;
    h) usage; exit 0      ;;
    *) usage; exit 1      ;;
  esac
done

# --- Ensure root ---
if (( EUID != 0 )); then
  echo -e "${C_RED}${ICON_FAIL} Please run as root.${C_NC}"
  exit 1
fi

# --- Temporary log & cleanup trap ---
LOGFILE=$(mktemp /tmp/zram_setup.XXXXXX)
trap 'rm -f "$LOGFILE"' EXIT

# --- Detect package manager ---
if   command -v apt-get &>/dev/null; then    PKG_INSTALL="apt-get install -y";  PKG_UPDATE="apt-get update -y"
elif command -v dnf &>/dev/null;    then    PKG_INSTALL="dnf install -y";      PKG_UPDATE="dnf check-update -y"
elif command -v pacman &>/dev/null; then    PKG_INSTALL="pacman -S --noconfirm"; PKG_UPDATE="pacman -Sy"
else
  echo -e "${C_RED}${ICON_FAIL} Unsupported distro.${C_NC}"
  exit 1
fi

# --- Detect service name ---
SERVICE_NAME=zramswap
if ! systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
  SERVICE_NAME=zram
fi

# --- Spinner-backed task runner ---
run_task(){
  local msg=$1; shift
  local cmd=( "$@" )
  printf "${C_BLUE}%s  %s... ${C_NC}" "$ICON_SETUP" "$msg"
  "${cmd[@]}" &> "$LOGFILE" &
  local pid=$!
  trap 'kill $pid 2>/dev/null; exit 1' INT TERM

  local spinner='|/-\'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\b${spinner:i++%${#spinner}:1}"
    sleep 0.1
  done

  if wait "$pid"; then
    printf "\b${C_GREEN}%s${C_NC}\n" "$ICON_OK"
  else
    printf "\b${C_RED}%s${C_NC}\n" "$ICON_FAIL"
    echo -e "${C_YELLOW}--- ERROR LOG ---${C_NC}" >&2
    cat "$LOGFILE" >&2
    exit 1
  fi
}

# --- Begin ---
echo -e "${C_BLUE}--- ${ICON_ROCKET} ZRAM Quick Setup ---${C_NC}"

run_task "Updating package lists" $PKG_UPDATE
run_task "Installing zram-tools"    $PKG_INSTALL zram-tools

# Backup existing config
if [[ -f /etc/default/zramswap ]]; then
  run_task "Backing up old config" cp /etc/default/zramswap{,.orig}
fi

# Write new config
run_task "Writing /etc/default/zramswap" bash -c "cat > /etc/default/zramswap <<EOF
ALGO=${ZRAM_ALGO}
PERCENT=${ZRAM_PERCENT}
PRIORITY=${ZRAM_PRIORITY}
EOF
"

# Restart service
run_task "Restarting ${SERVICE_NAME} service" systemctl restart "${SERVICE_NAME}.service"

# --- Final Summary ---
echo
echo -e "${C_GREEN}--- ${ICON_OK} ZRAM is Active! ---${C_NC}"
SWAP_INFO=$(swapon --show=NAME,SIZE,PRIO --bytes | grep zram)
if [[ -z "$SWAP_INFO" ]]; then
  echo -e "${C_RED}${ICON_FAIL} No zram device detected!${C_NC}"
  exit 1
fi

# Pretty‑print with printf
IFS=$'\n' read -r name size prio <<<"$(awk '{print $1,$2,$3}' <<<"$SWAP_INFO")"
printf "╭────────────────────────────────────╮\n"
printf "│ %-10s : %-12s │\n" "Device"   "$name"
printf "│ %-10s : %-12s │\n" "Size"     "$size"
printf "│ %-10s : %-12s │\n" "Priority" "$prio"
printf "╰────────────────────────────────────╯\n"

echo -e "${C_YELLOW}Configured ALGO=${ZRAM_ALGO}, PERCENT=${ZRAM_PERCENT}%, PRIORITY=${ZRAM_PRIORITY}${C_NC}"
