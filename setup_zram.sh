#!/usr/bin/env bash

#
# ZRAM Quick Setup Script 
# Usage: sudo ./zram-setup.sh [-p percent] [-a algo] [-r priority] [-h]
#

set -eo pipefail

# --- Defaults ---
ZRAM_PERCENT=69
ZRAM_ALGO=zstd
ZRAM_PRIORITY=100

# --- Clean Colors ---
C_CYAN="\033[96m"
C_GREEN="\033[92m"
C_YELLOW="\033[93m"
C_RED="\033[91m"
C_BLUE="\033[94m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_NC="\033[0m"

# --- Simple Icons ---
OK="✓"
FAIL="✗"
ARROW="→"
DOT="•"

# --- Clean Header ---
print_header() {
  echo -e "${C_CYAN}${C_BOLD}┌─────────────────────────────────────────┐${C_NC}"
  echo -e "${C_CYAN}${C_BOLD}│          ZRAM SETUP UTILITY             │${C_NC}"
  echo -e "${C_CYAN}${C_BOLD}└─────────────────────────────────────────┘${C_NC}"
}

# --- Usage ---
usage(){
  echo -e "${C_BOLD}Usage:${C_NC} sudo $0 [options]"
  echo
  echo -e "${C_YELLOW}Options:${C_NC}"
  echo -e "  -p NUM    ZRAM size % of RAM (default: ${ZRAM_PERCENT})"
  echo -e "  -a ALGO   Compression (default: ${ZRAM_ALGO})"
  echo -e "  -r NUM    Priority (default: ${ZRAM_PRIORITY})"
  echo -e "  -h        Show help"
  echo
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

# --- Root check ---
if (( EUID != 0 )); then
  echo -e "${C_RED}${FAIL} Root privileges required${C_NC}"
  exit 1
fi

# --- Temporary log ---
LOGFILE=$(mktemp /tmp/zram_setup.XXXXXX)
trap 'rm -f "$LOGFILE"' EXIT

# --- Package manager detection ---
detect_pm() {
  if   command -v apt-get &>/dev/null; then PKG_INSTALL="apt-get install -y"; PKG_UPDATE="apt-get update -y"; DISTRO="debian"
  elif command -v dnf &>/dev/null;     then PKG_INSTALL="dnf install -y";     PKG_UPDATE="dnf check-update -y"; DISTRO="fedora"
  elif command -v pacman &>/dev/null;  then PKG_INSTALL="pacman -S --noconfirm"; PKG_UPDATE="pacman -Sy"; DISTRO="arch"
  else echo -e "${C_RED}${FAIL} Unsupported distribution${C_NC}"; exit 1; fi
}

# --- Service detection ---
detect_service() {
  SERVICE_NAME=zramswap
  if ! systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}.service"; then
    SERVICE_NAME=zram
  fi
}

# --- Clean task runner ---
run_task(){
  local msg=$1; shift
  printf "${C_BLUE}${DOT}${C_NC} %-35s " "$msg"
  if "$@" &> "$LOGFILE"; then
    echo -e "${C_GREEN}${OK}${C_NC}"
  else
    echo -e "${C_RED}${FAIL}${C_NC}"
    echo -e "${C_RED}Error details:${C_NC}" >&2
    cat "$LOGFILE" >&2
    exit 1
  fi
}

# --- Get system info ---
get_system_info() {
  TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_RAM_GB=$(echo "scale=1; $TOTAL_RAM_KB/1024/1024" | bc)
  KERNEL_VER=$(uname -r)
  DISTRO_NAME=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 | head -1)
}

# --- Show current memory status ---
show_memory_status() {
  local physical_ram=$(free -h | awk '/^Mem:/ {print $2}')
  local used_ram=$(free -h | awk '/^Mem:/ {print $3}')
  local available_ram=$(free -h | awk '/^Mem:/ {print $7}')
  
  echo -e "${C_BOLD}Current Memory Status:${C_NC}"
  printf "  Physical RAM: %s (Used: %s, Available: %s)\n" "$physical_ram" "$used_ram" "$available_ram"
  
  # Show existing swap
  local existing_swap=$(swapon --show --noheadings 2>/dev/null | wc -l)
  if [[ $existing_swap -gt 0 ]]; then
    echo -e "  Existing swap devices: ${existing_swap}"
    swapon --show 2>/dev/null | sed 's/^/    /'
  else
    echo -e "  No existing swap devices"
  fi
}

# --- Main execution ---
main() {
  clear
  print_header
  
  # System detection
  get_system_info
  detect_pm
  detect_service
  
  # Show system info compactly
  echo -e "${C_BOLD}System:${C_NC} $DISTRO_NAME | ${C_BOLD}Kernel:${C_NC} $KERNEL_VER | ${C_BOLD}RAM:${C_NC} ${TOTAL_RAM_GB}GB"
  echo -e "${C_BOLD}Config:${C_NC} ${ZRAM_PERCENT}% RAM, ${ZRAM_ALGO} compression, priority ${ZRAM_PRIORITY}"
  echo
  
  show_memory_status
  echo
  
  echo -e "${C_BOLD}Installation Steps:${C_NC}"
  
  # Installation tasks
  run_task "Updating package repositories" $PKG_UPDATE
  run_task "Installing zram-tools" $PKG_INSTALL zram-tools
  
  # Kernel modules
  KERNEL_VERSION=$(uname -r)
  case "$DISTRO" in
    "debian") run_task "Installing kernel modules" $PKG_INSTALL "linux-modules-extra-${KERNEL_VERSION}" ;;
    "fedora") run_task "Installing kernel modules" $PKG_INSTALL "kernel-modules-${KERNEL_VERSION}" ;;
    "arch")   run_task "Verifying kernel modules" echo "Modules included with kernel" ;;
  esac
  
  # Configuration
  if [[ -f /etc/default/zramswap ]]; then
    run_task "Backing up existing config" cp /etc/default/zramswap{,.backup}
  fi
  
  run_task "Writing ZRAM configuration" bash -c "cat > /etc/default/zramswap <<EOF
ALGO=${ZRAM_ALGO}
PERCENT=${ZRAM_PERCENT}
PRIORITY=${ZRAM_PRIORITY}
EOF"
  
  run_task "Starting ZRAM service" systemctl restart "${SERVICE_NAME}.service"
  run_task "Enabling ZRAM at boot" systemctl enable "${SERVICE_NAME}.service"
  
  echo
}

# --- Final status ---
show_final_status() {
  echo -e "${C_GREEN}${C_BOLD}${OK} ZRAM Setup Complete!${C_NC}"
  echo
  
  # Get current memory info after setup
  local physical_ram=$(free -h | awk '/^Mem:/ {print $2}')
  local used_ram=$(free -h | awk '/^Mem:/ {print $3}')
  local available_ram=$(free -h | awk '/^Mem:/ {print $7}')
  
  echo -e "${C_BOLD}Memory Summary:${C_NC}"
  printf "  ${C_BLUE}Physical RAM:${C_NC} %s (Used: %s, Available: %s)\n" "$physical_ram" "$used_ram" "$available_ram"
  
  # Show ZRAM details
  local zram_info=$(swapon --show --noheadings 2>/dev/null | grep zram || echo "")
  if [[ -n "$zram_info" ]]; then
    local zram_name=$(echo "$zram_info" | awk '{print $1}')
    local zram_size=$(echo "$zram_info" | awk '{print $2}')
    local zram_prio=$(echo "$zram_info" | awk '{print $4}')
    
    printf "  ${C_GREEN}ZRAM Swap:${C_NC}    %s (%s, Priority: %s)\n" "$zram_size" "$zram_name" "$zram_prio"
    
    # Calculate compression stats if available
    if [[ -r /sys/block/zram0/mm_stat ]]; then
      local mm_stat=($(cat /sys/block/zram0/mm_stat))
      local orig_size=$((mm_stat[0]))
      local comp_size=$((mm_stat[1]))
      if [[ $orig_size -gt 0 ]]; then
        local ratio=$(echo "scale=1; $orig_size/$comp_size" | bc 2>/dev/null || echo "N/A")
        printf "  ${C_YELLOW}Compression:${C_NC}  ${ratio}:1 ratio using ${ZRAM_ALGO}\n"
      fi
    fi
  else
    echo -e "  ${C_RED}${FAIL} ZRAM device not found!${C_NC}"
    exit 1
  fi
  
  echo
  echo -e "${C_BOLD}Quick Commands:${C_NC}"
  echo -e "  Status: ${C_DIM}sudo systemctl status ${SERVICE_NAME}${C_NC}"
  echo -e "  Check:  ${C_DIM}swapon --show${C_NC}"
  echo -e "  Stats:  ${C_DIM}cat /proc/swaps${C_NC}"
}

# --- Error handler ---
error_handler() {
  echo -e "\n${C_RED}${FAIL} Setup failed. Check logs above.${C_NC}"
  exit 1
}

trap error_handler ERR INT TERM

# --- Execute ---
main
show_final_status
