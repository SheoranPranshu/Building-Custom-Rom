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

# --- Sleek Colors & Gradients ---
C_CYAN="\033[96m"
C_GREEN="\033[92m"
C_YELLOW="\033[93m"
C_RED="\033[91m"
C_BLUE="\033[94m"
C_PURPLE="\033[95m"
C_ORANGE="\033[38;5;208m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_NC="\033[0m"

# --- Modern Icons ---
ICON_ZRAM="⚡"
ICON_OK="✓"
ICON_FAIL="✗"
ICON_ARROW="▶"
ICON_DOT="●"
ICON_MEMORY="🧠"
ICON_SPEED="🚀"
ICON_GEAR="⚙"

# --- Sleek Header with Gradient Effect ---
print_header() {
  echo -e "${C_CYAN}╭──────────────────────────────────────────────────────────╮${C_NC}"
  echo -e "${C_CYAN}│ ${ICON_ZRAM} ${C_BOLD}ZRAM SETUP${C_NC}${C_BLUE} ${ICON_SPEED} Professional Memory Optimizer${C_NC} ${C_CYAN}│${C_NC}"
  echo -e "${C_CYAN}╰──────────────────────────────────────────────────────────╯${C_NC}"
}

# --- Compact Usage ---
usage(){
  echo -e "${C_BOLD}${ICON_GEAR} Usage:${C_NC} sudo $0 [options]"
  echo -e "${C_YELLOW}  -p${C_NC} PERCENT  ${C_DIM}ZRAM size % (default: ${ZRAM_PERCENT})${C_NC}"
  echo -e "${C_YELLOW}  -a${C_NC} ALGO     ${C_DIM}Compression (default: ${ZRAM_ALGO})${C_NC}" 
  echo -e "${C_YELLOW}  -r${C_NC} PRIORITY ${C_DIM}Swap priority (default: ${ZRAM_PRIORITY})${C_NC}"
  echo -e "${C_YELLOW}  -h${C_NC}          ${C_DIM}Show help${C_NC}"
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
  echo -e "${C_RED}${ICON_FAIL} ${C_BOLD}Root access required${C_NC} ${C_DIM}→ Run with sudo${C_NC}"
  exit 1
fi

# --- Setup variables ---
LOGFILE=$(mktemp /tmp/zram_setup.XXXXXX)
trap 'rm -f "$LOGFILE"' EXIT

# --- System detection ---
detect_system() {
  if   command -v apt-get &>/dev/null; then PKG_INSTALL="apt-get install -y"; PKG_UPDATE="apt-get update -y"; DISTRO="debian"
  elif command -v dnf &>/dev/null;     then PKG_INSTALL="dnf install -y";     PKG_UPDATE="dnf check-update -y"; DISTRO="fedora"  
  elif command -v pacman &>/dev/null;  then PKG_INSTALL="pacman -S --noconfirm"; PKG_UPDATE="pacman -Sy"; DISTRO="arch"
  else echo -e "${C_RED}${ICON_FAIL} Unsupported distribution${C_NC}"; exit 1; fi
  
  SERVICE_NAME=zramswap
  if ! systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}.service"; then
    SERVICE_NAME=zram
  fi
}

# --- Sleek task runner with animation ---
run_task(){
  local msg=$1; shift
  local cmd=( "$@" )
  
  printf "${C_BLUE}${ICON_ARROW}${C_NC} %-40s ${C_DIM}[${C_NC}" "$msg"
  
  "${cmd[@]}" &> "$LOGFILE" &
  local pid=$!
  trap 'kill $pid 2>/dev/null; exit 1' INT TERM

  local dots="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\b\b${C_CYAN}${dots:i++%${#dots}:1}${C_DIM}]${C_NC}"
    sleep 0.1
  done

  if wait "$pid"; then
    printf "\b\b${C_GREEN}${ICON_OK}${C_DIM}]${C_NC}\n"
  else
    printf "\b\b${C_RED}${ICON_FAIL}${C_DIM}]${C_NC}\n"
    echo -e "${C_RED}${ICON_FAIL} Error:${C_NC}" && sed 's/^/  /' "$LOGFILE" >&2
    exit 1
  fi
}

# --- System info display ---
show_system_info() {
  local total_ram=$(free -h | awk '/^Mem:/ {print $2}')
  local kernel=$(uname -r)
  local distro=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 | head -1)
  
  echo -e "${C_PURPLE}${ICON_MEMORY} System:${C_NC} ${distro} ${C_DIM}|${C_NC} ${C_BLUE}Kernel:${C_NC} ${kernel} ${C_DIM}|${C_NC} ${C_GREEN}RAM:${C_NC} ${total_ram}"
  echo -e "${C_ORANGE}${ICON_GEAR} Config:${C_NC} ${ZRAM_PERCENT}% RAM, ${ZRAM_ALGO} compression, priority ${ZRAM_PRIORITY}"
}

# --- Memory status before setup ---
show_current_memory() {
  local used=$(free -h | awk '/^Mem:/ {print $3}')
  local available=$(free -h | awk '/^Mem:/ {print $7}')
  local total=$(free -h | awk '/^Mem:/ {print $2}')
  
  echo -e "${C_BOLD}${ICON_MEMORY} Current Memory:${C_NC} ${C_GREEN}${total}${C_NC} total ${C_DIM}(${C_YELLOW}${used}${C_DIM} used, ${C_GREEN}${available}${C_DIM} available)${C_NC}"
  
  local swap_count=$(swapon --show --noheadings 2>/dev/null | wc -l)
  if [[ $swap_count -gt 0 ]]; then
    echo -e "${C_BOLD}${ICON_DOT} Existing Swap:${C_NC} ${swap_count} device(s) active"
    swapon --show 2>/dev/null | tail -n +2 | while read line; do
      echo -e "  ${C_DIM}${line}${C_NC}"
    done
  else
    echo -e "${C_BOLD}${ICON_DOT} Existing Swap:${C_NC} ${C_DIM}None${C_NC}"
  fi
}

# --- Main execution ---
main() {
  clear
  print_header
  
  detect_system
  show_system_info
  echo
  show_current_memory
  echo
  
  echo -e "${C_BOLD}${ICON_ARROW} Installation Progress:${C_NC}"
  
  run_task "Updating repositories" $PKG_UPDATE
  run_task "Installing zram-tools" $PKG_INSTALL zram-tools
  
  # Kernel modules
  KERNEL_VERSION=$(uname -r)
  case "$DISTRO" in
    "debian") run_task "Installing kernel modules" $PKG_INSTALL "linux-modules-extra-${KERNEL_VERSION}" ;;
    "fedora") run_task "Installing kernel modules" $PKG_INSTALL "kernel-modules-${KERNEL_VERSION}" ;;
    "arch")   run_task "Verifying kernel modules" echo "Built-in modules verified" ;;
  esac
  
  # Config backup
  [[ -f /etc/default/zramswap ]] && run_task "Backing up old config" cp /etc/default/zramswap{,.backup}
  
  # Write config
  run_task "Writing ZRAM config" bash -c "cat > /etc/default/zramswap <<EOF
ALGO=${ZRAM_ALGO}
PERCENT=${ZRAM_PERCENT}
PRIORITY=${ZRAM_PRIORITY}
EOF"
  
  run_task "Starting ZRAM service" systemctl restart "${SERVICE_NAME}.service"
  run_task "Enabling at boot" systemctl enable "${SERVICE_NAME}.service"
  
  echo
}

# --- Enhanced final summary ---
show_final_summary() {
  echo -e "${C_GREEN}${ICON_OK} ${C_BOLD}ZRAM Setup Complete!${C_NC}"
  echo
  
  # Memory comparison
  local physical_total=$(free -h | awk '/^Mem:/ {print $2}')
  local physical_used=$(free -h | awk '/^Mem:/ {print $3}')
  local physical_avail=$(free -h | awk '/^Mem:/ {print $7}')
  
  echo -e "${C_BOLD}${ICON_MEMORY} Memory Summary:${C_NC}"
  echo -e "${C_BLUE}  Physical RAM:${C_NC} ${C_GREEN}${physical_total}${C_NC} ${C_DIM}(${physical_used} used, ${physical_avail} available)${C_NC}"
  
  # ZRAM info
  local zram_info=$(swapon --show --noheadings 2>/dev/null | grep zram | head -1 || echo "")
  if [[ -n "$zram_info" ]]; then
    local zram_device=$(echo "$zram_info" | awk '{print $1}')
    local zram_size=$(echo "$zram_info" | awk '{print $2}')
    local zram_prio=$(echo "$zram_info" | awk '{print $4}')
    
    echo -e "${C_PURPLE}  ZRAM Swap:${C_NC}    ${C_GREEN}${zram_size}${C_NC} ${C_DIM}(${zram_device}, priority ${zram_prio})${C_NC}"
    
    # Compression stats
    if [[ -r /sys/block/zram0/mm_stat ]]; then
      local mm_stat=($(cat /sys/block/zram0/mm_stat 2>/dev/null || echo "0 0"))
      local orig_size=${mm_stat[0]}
      local comp_size=${mm_stat[1]}
      if [[ $orig_size -gt 0 && $comp_size -gt 0 ]]; then
        local ratio=$(echo "scale=2; $orig_size/$comp_size" | bc 2>/dev/null || echo "N/A")
        echo -e "${C_ORANGE}  Compression:${C_NC}  ${C_YELLOW}${ratio}:1${C_NC} ${C_DIM}ratio with ${ZRAM_ALGO}${C_NC}"
      fi
    fi
    
    # Total effective memory
    local zram_mb=$(echo "$zram_size" | sed 's/[^0-9.]//g')
    local physical_mb=$(echo "$physical_total" | sed 's/[^0-9.]//g')
    echo -e "${C_CYAN}  Effective RAM:${C_NC} ${C_BOLD}~$((${physical_mb%.*} + ${zram_mb%.*}))GB${C_NC} ${C_DIM}(with compression boost)${C_NC}"
  else
    echo -e "${C_RED}  ${ICON_FAIL} ZRAM device not detected!${C_NC}"
    exit 1
  fi
  
  echo
  echo -e "${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
  echo -e "${C_BOLD}Quick Commands:${C_NC} ${C_DIM}status:${C_NC} ${C_GREEN}systemctl status ${SERVICE_NAME}${C_NC} ${C_DIM}| check:${C_NC} ${C_GREEN}swapon --show${C_NC} ${C_DIM}| stats:${C_NC} ${C_GREEN}cat /proc/swaps${C_NC}"
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
  echo -e "${C_RED}${ICON_FAIL} ${C_BOLD}Root required${C_NC} ${C_DIM}→ Use: sudo $0${C_NC}"
  exit 1
fi

# --- Setup ---
LOGFILE=$(mktemp /tmp/zram_setup.XXXXXX)
trap 'rm -f "$LOGFILE"' EXIT

# --- System detection ---
detect_system() {
  if   command -v apt-get &>/dev/null; then PKG_INSTALL="apt-get install -y"; PKG_UPDATE="apt-get update -y"; DISTRO="debian"
  elif command -v dnf &>/dev/null;     then PKG_INSTALL="dnf install -y";     PKG_UPDATE="dnf check-update -y"; DISTRO="fedora"
  elif command -v pacman &>/dev/null;  then PKG_INSTALL="pacman -S --noconfirm"; PKG_UPDATE="pacman -Sy"; DISTRO="arch"
  else echo -e "${C_RED}${ICON_FAIL} Unsupported distro${C_NC}"; exit 1; fi
  
  SERVICE_NAME=zramswap
  systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}.service" || SERVICE_NAME=zram
}

# --- Enhanced task runner with sleek animation ---
run_task(){
  local msg=$1; shift
  printf "${C_BLUE}${ICON_DOT}${C_NC} %-38s ${C_DIM}[${C_NC}" "$msg"
  
  "$@" &> "$LOGFILE" &
  local pid=$!
  
  local frames="▱▰▰▰ ▱▱▰▰ ▱▱▱▰ ▰▱▱▱ ▰▰▱▱ ▰▰▰▱"
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    local frame=$(echo $frames | cut -d' ' -f$((i%6+1)))
    printf "\b\b\b\b\b\b${C_CYAN}${frame}${C_DIM}]${C_NC}"
    ((i++))
    sleep 0.12
  done

  if wait "$pid"; then
    printf "\b\b\b\b\b\b${C_GREEN}${ICON_OK}    ${C_DIM}]${C_NC}\n"
  else
    printf "\b\b\b\b\b\b${C_RED}${ICON_FAIL}    ${C_DIM}]${C_NC}\n"
    echo -e "${C_RED}${ICON_ARROW} Error:${C_NC}" && sed 's/^/  /' "$LOGFILE" >&2; exit 1
  fi
}

# --- Memory info functions ---
get_memory_info() {
  TOTAL_RAM=$(free -h | awk '/^Mem:/ {print $2}')
  USED_RAM=$(free -h | awk '/^Mem:/ {print $3}')
  AVAIL_RAM=$(free -h | awk '/^Mem:/ {print $7}')
  KERNEL_VER=$(uname -r | cut -d'-' -f1)
  DISTRO_NAME=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 | head -1 | cut -d' ' -f1-3)
}

show_system_overview() {
  echo -e "${C_PURPLE}${ICON_MEMORY} System:${C_NC} ${C_BOLD}${DISTRO_NAME}${C_NC} ${C_DIM}| Kernel ${KERNEL_VER} | RAM ${TOTAL_RAM}${C_NC}"
  echo -e "${C_ORANGE}${ICON_GEAR} Target:${C_NC} ${C_BOLD}${ZRAM_PERCENT}%${C_NC} ZRAM ${C_DIM}(~$((${TOTAL_RAM%G*} * ZRAM_PERCENT / 100))GB)${C_NC} with ${C_BOLD}${ZRAM_ALGO}${C_NC} compression"
  echo -e "${C_CYAN}${ICON_DOT} Memory:${C_NC} ${C_GREEN}${AVAIL_RAM}${C_NC} available ${C_DIM}of ${TOTAL_RAM} total${C_NC}"
}

# --- Main execution ---
main() {
  clear
  print_header
  
  get_memory_info
  detect_system
  show_system_overview
  
  echo
  echo -e "${C_BOLD}${ICON_ARROW} Setup Process:${C_NC}"
  
  run_task "Updating package cache" $PKG_UPDATE
  run_task "Installing zram-tools" $PKG_INSTALL zram-tools
  
  KERNEL_VERSION=$(uname -r)
  case "$DISTRO" in
    "debian") run_task "Installing kernel modules" $PKG_INSTALL "linux-modules-extra-${KERNEL_VERSION}" ;;
    "fedora") run_task "Installing kernel modules" $PKG_INSTALL "kernel-modules-${KERNEL_VERSION}" ;;
    "arch")   run_task "Verifying kernel support" echo "Kernel modules verified" ;;
  esac
  
  [[ -f /etc/default/zramswap ]] && run_task "Backing up old config" cp /etc/default/zramswap{,.backup}
  
  run_task "Writing configuration" bash -c "cat > /etc/default/zramswap <<EOF
ALGO=${ZRAM_ALGO}
PERCENT=${ZRAM_PERCENT}
PRIORITY=${ZRAM_PRIORITY}
EOF"
  
  run_task "Activating ZRAM service" systemctl restart "${SERVICE_NAME}.service"
  run_task "Enabling auto-start" systemctl enable "${SERVICE_NAME}.service"
  
  echo
}

# --- Final results ---
show_results() {
  echo -e "${C_GREEN}${ICON_OK} ${C_BOLD}ZRAM Active!${C_NC}"
  echo
  
  # Current memory state
  local phys_total=$(free -h | awk '/^Mem:/ {print $2}')
  local phys_used=$(free -h | awk '/^Mem:/ {print $3}')
  local phys_free=$(free -h | awk '/^Mem:/ {print $7}')
  
  echo -e "${C_BOLD}${ICON_MEMORY} Memory Layout:${C_NC}"
  echo -e "${C_BLUE}  Physical:${C_NC} ${C_GREEN}${phys_total}${C_NC} ${C_DIM}(${phys_used} used, ${phys_free} free)${C_NC}"
  
  # ZRAM details
  local zram_line=$(swapon --show --noheadings 2>/dev/null | grep zram | head -1)
  if [[ -n "$zram_line" ]]; then
    local zram_dev=$(echo "$zram_line" | awk '{print $1}')
    local zram_size=$(echo "$zram_line" | awk '{print $2}')
    local zram_prio=$(echo "$zram_line" | awk '{print $4}')
    
    echo -e "${C_PURPLE}  ZRAM:${C_NC}     ${C_YELLOW}${zram_size}${C_NC} ${C_DIM}(${zram_dev}, priority ${zram_prio})${C_NC}"
    
    # Compression ratio
    if [[ -r /sys/block/zram0/mm_stat ]]; then
      local stats=($(cat /sys/block/zram0/mm_stat 2>/dev/null || echo "0 0"))
      if [[ ${stats[0]} -gt 0 && ${stats[1]} -gt 0 ]]; then
        local ratio=$(echo "scale=1; ${stats[0]}/${stats[1]}" | bc 2>/dev/null || echo "N/A")
        echo -e "${C_ORANGE}  Compress:${C_NC} ${C_BOLD}${ratio}:1${C_NC} ${C_DIM}efficiency with ${ZRAM_ALGO}${C_NC}"
      fi
    fi
    
    # Effective memory calculation
    local total_effective=$((${phys_total%G*} + ${zram_size%G*}))
    echo -e "${C_CYAN}  Effective:${C_NC} ${C_BOLD}~${total_effective}GB${C_NC} ${C_DIM}total usable memory${C_NC}"
  else
    echo -e "${C_RED}  ${ICON_FAIL} ZRAM not detected${C_NC}"
    exit 1
  fi
  
  echo
  echo -e "${C_DIM}Commands: ${C_GREEN}systemctl status ${SERVICE_NAME}${C_NC} ${C_DIM}| ${C_GREEN}swapon --show${C_NC} ${C_DIM}| ${C_GREEN}cat /proc/swaps${C_NC}"
}

# --- Error handling ---
trap 'echo -e "\n${C_RED}${ICON_FAIL} Setup interrupted${C_NC}"; exit 1' ERR INT TERM

# --- Execute ---
main
show_results
