#!/usr/bin/env bash

#
# ZRAM Quick Setup Script
# Usage: sudo ./zram-setup.sh [-p percent] [-a algo] [-r priority] [-h]
#

set -eo pipefail

# --- Script Info ---
SCRIPT_NAME="ZRAM Quick Setup"
SCRIPT_VERSION="2.1.0"
SCRIPT_AUTHOR="Enhanced Professional Edition"

# --- Defaults (override with flags) ---
ZRAM_PERCENT=69
ZRAM_ALGO=zstd
ZRAM_PRIORITY=100

# --- Enhanced Colors & Styling ---
C_HEADER="\033[1;36m"     # Bright Cyan
C_BLUE="\033[1;34m"       # Bright Blue
C_GREEN="\033[1;32m"      # Bright Green
C_YELLOW="\033[1;33m"     # Bright Yellow
C_RED="\033[1;31m"        # Bright Red
C_PURPLE="\033[1;35m"     # Bright Purple
C_GRAY="\033[0;37m"       # Light Gray
C_BOLD="\033[1m"          # Bold
C_DIM="\033[2m"           # Dim
C_NC="\033[0m"            # No Color

# --- Professional Icons ---
ICON_SETUP="⚙️ "
ICON_OK="✅"
ICON_FAIL="❌"
ICON_INFO="ℹ️ "
ICON_ROCKET="🚀"
ICON_GEAR="⚡"
ICON_SHIELD="🛡️ "
ICON_MEMORY="💾"
ICON_SPEED="⚡"

# --- Professional Banner ---
print_banner() {
  local width=70
  echo -e "${C_HEADER}"
  printf "╔═%.0s╗\n" $(seq 1 $((width-2)))
  printf "║%*s║\n" $((width-2)) ""
  printf "║%*s%s%*s║\n" $(((width-2-${#SCRIPT_NAME})/2)) "" "$SCRIPT_NAME" $(((width-2-${#SCRIPT_NAME})/2)) ""
  printf "║%*s%s v%s%*s║\n" $(((width-2-${#SCRIPT_VERSION}-3)/2)) "" "Professional Edition" "$SCRIPT_VERSION" $(((width-2-${#SCRIPT_VERSION}-3)/2)) ""
  printf "║%*s║\n" $((width-2)) ""
  printf "╚═%.0s╝\n" $(seq 1 $((width-2)))
  echo -e "${C_NC}"
}

# --- Enhanced Usage message ---
usage(){
  echo -e "${C_HEADER}╭─────────────────────────────────────────────────────────╮${C_NC}"
  echo -e "${C_HEADER}│                      ${C_BOLD}USAGE GUIDE${C_NC}${C_HEADER}                         │${C_NC}"
  echo -e "${C_HEADER}╰─────────────────────────────────────────────────────────╯${C_NC}"
  echo
  echo -e "${C_BLUE}${ICON_INFO}${C_BOLD}Syntax:${C_NC} ${C_GREEN}sudo $0 [options]${C_NC}"
  echo
  echo -e "${C_PURPLE}${C_BOLD}Options:${C_NC}"
  echo -e "  ${C_YELLOW}-p PERCENT${C_NC}   ${C_GRAY}ZRAM size as % of RAM${C_NC} ${C_DIM}(default: ${ZRAM_PERCENT}%)${C_NC}"
  echo -e "  ${C_YELLOW}-a ALGO${C_NC}      ${C_GRAY}Compression algorithm${C_NC} ${C_DIM}(default: ${ZRAM_ALGO})${C_NC}"
  echo -e "  ${C_YELLOW}-r PRIORITY${C_NC}  ${C_GRAY}Swap priority level${C_NC}    ${C_DIM}(default: ${ZRAM_PRIORITY})${C_NC}"
  echo -e "  ${C_YELLOW}-h${C_NC}           ${C_GRAY}Show this help and exit${C_NC}"
  echo
  echo -e "${C_BLUE}${C_BOLD}Examples:${C_NC}"
  echo -e "  ${C_GREEN}sudo $0 -p 50 -a lz4${C_NC}     ${C_GRAY}# 50% RAM, LZ4 compression${C_NC}"
  echo -e "  ${C_GREEN}sudo $0 -r 200${C_NC}           ${C_GRAY}# Higher priority swap${C_NC}"
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

# --- Professional privilege check ---
check_privileges() {
  if (( EUID != 0 )); then
    echo -e "${C_RED}╭─────────────────────────────────────╮${C_NC}"
    echo -e "${C_RED}│ ${ICON_FAIL} ${C_BOLD}ROOT PRIVILEGES REQUIRED${C_NC}${C_RED}     │${C_NC}"
    echo -e "${C_RED}╰─────────────────────────────────────╯${C_NC}"
    echo -e "${C_YELLOW}${ICON_INFO}Please run with: ${C_GREEN}sudo $0${C_NC}"
    exit 1
  fi
}

# --- System info display ---
show_system_info() {
  local total_ram=$(free -h | awk '/^Mem:/ {print $2}')
  local kernel_ver=$(uname -r)
  local distro=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
  
  echo -e "${C_HEADER}╭─────────────────────────────────────────────────────────╮${C_NC}"
  echo -e "${C_HEADER}│                   ${C_BOLD}SYSTEM INFORMATION${C_NC}${C_HEADER}                   │${C_NC}"
  echo -e "${C_HEADER}╰─────────────────────────────────────────────────────────╯${C_NC}"
  echo -e "${C_BLUE}${ICON_MEMORY}${C_BOLD}Total RAM:${C_NC}     ${C_GREEN}${total_ram}${C_NC}"
  echo -e "${C_BLUE}${ICON_GEAR}${C_BOLD}Kernel:${C_NC}        ${C_GREEN}${kernel_ver}${C_NC}"
  echo -e "${C_BLUE}${ICON_SHIELD}${C_BOLD}Distribution:${C_NC}  ${C_GREEN}${distro}${C_NC}"
  echo
}

# --- Configuration display ---
show_config() {
  echo -e "${C_PURPLE}╭─────────────────────────────────────────────────────────╮${C_NC}"
  echo -e "${C_PURPLE}│                  ${C_BOLD}CONFIGURATION SETTINGS${C_NC}${C_PURPLE}                 │${C_NC}"
  echo -e "${C_PURPLE}╰─────────────────────────────────────────────────────────╯${C_NC}"
  echo -e "${C_YELLOW}${ICON_MEMORY}${C_BOLD}ZRAM Size:${C_NC}       ${C_GREEN}${ZRAM_PERCENT}% of RAM${C_NC}"
  echo -e "${C_YELLOW}${ICON_SPEED}${C_BOLD}Algorithm:${C_NC}       ${C_GREEN}${ZRAM_ALGO}${C_NC}"
  echo -e "${C_YELLOW}${ICON_GEAR}${C_BOLD}Priority:${C_NC}        ${C_GREEN}${ZRAM_PRIORITY}${C_NC}"
  echo
}

# --- Temporary log & cleanup trap ---
LOGFILE=$(mktemp /tmp/zram_setup.XXXXXX)
trap 'rm -f "$LOGFILE"' EXIT

# --- Enhanced package manager detection ---
detect_package_manager() {
  if   command -v apt-get &>/dev/null; then
    PKG_CMD="apt-get"
    PKG_INSTALL="apt-get install -y"
    PKG_UPDATE="apt-get update -y"
    DISTRO_TYPE="debian"
  elif command -v dnf &>/dev/null; then
    PKG_CMD="dnf"
    PKG_INSTALL="dnf install -y"
    PKG_UPDATE="dnf check-update -y"
    DISTRO_TYPE="fedora"
  elif command -v pacman &>/dev/null; then
    PKG_CMD="pacman"
    PKG_INSTALL="pacman -S --noconfirm"
    PKG_UPDATE="pacman -Sy"
    DISTRO_TYPE="arch"
  else
    echo -e "${C_RED}╭─────────────────────────────────────╮${C_NC}"
    echo -e "${C_RED}│ ${ICON_FAIL} ${C_BOLD}UNSUPPORTED DISTRIBUTION${C_NC}${C_RED}     │${C_NC}"
    echo -e "${C_RED}╰─────────────────────────────────────╯${C_NC}"
    echo -e "${C_YELLOW}${ICON_INFO}Supported: Debian/Ubuntu, Fedora/RHEL, Arch Linux${C_NC}"
    exit 1
  fi
}

# --- Enhanced service detection ---
detect_service() {
  SERVICE_NAME=zramswap
  if ! systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}.service"; then
    SERVICE_NAME=zram
    if ! systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}.service"; then
      echo -e "${C_YELLOW}${ICON_INFO}No existing ZRAM service found. Will install fresh.${C_NC}"
    fi
  fi
}

# --- Enhanced spinner-backed task runner ---
run_task(){
  local msg=$1; shift
  local cmd=( "$@" )
  
  # Enhanced status line
  printf "${C_BLUE}${ICON_SETUP}${C_BOLD}%-40s${C_NC}" "$msg"
  printf "${C_DIM}[${C_NC}"
  
  "${cmd[@]}" &> "$LOGFILE" &
  local pid=$!
  trap 'kill $pid 2>/dev/null; exit 1' INT TERM

  # Professional spinner
  local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\b\b${C_BLUE}${spinner:i++%${#spinner}:1}${C_DIM}]${C_NC}"
    sleep 0.08
  done

  if wait "$pid"; then
    printf "\b\b${C_GREEN}${ICON_OK}${C_DIM}]${C_NC}\n"
  else
    printf "\b\b${C_RED}${ICON_FAIL}${C_DIM}]${C_NC}\n"
    echo
    echo -e "${C_RED}╭─────────────────────────────────────────────────────────╮${C_NC}"
    echo -e "${C_RED}│                    ${C_BOLD}ERROR DETAILS${C_NC}${C_RED}                        │${C_NC}"
    echo -e "${C_RED}╰─────────────────────────────────────────────────────────╯${C_NC}"
    sed 's/^/  /' "$LOGFILE" >&2
    exit 1
  fi
}

# --- Progress bar function ---
show_progress() {
  local current=$1
  local total=$2
  local width=40
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  
  printf "\r${C_BLUE}Progress: ${C_NC}["
  printf "%*s" $filled | tr ' ' '█'
  printf "%*s" $((width - filled)) | tr ' ' '░'
  printf "] ${C_BOLD}%d%%${C_NC}" $percentage
}

# --- Main execution starts here ---
main() {
  # Clear screen for professional look
  clear
  
  # Show banner
  print_banner
  
  # System checks
  check_privileges
  show_system_info
  show_config
  
  # Progress tracking
  local total_steps=6
  local current_step=0
  
  echo -e "${C_HEADER}╭─────────────────────────────────────────────────────────╮${C_NC}"
  echo -e "${C_HEADER}│                  ${C_BOLD}INSTALLATION PROGRESS${C_NC}${C_HEADER}                  │${C_NC}"
  echo -e "${C_HEADER}╰─────────────────────────────────────────────────────────╯${C_NC}"
  echo
  
  # Step 1: Detect package manager
  ((current_step++))
  show_progress $current_step $total_steps
  detect_package_manager
  printf "\n"
  run_task "Detecting package manager (${PKG_CMD})" echo "Package manager: $PKG_CMD"
  
  # Step 2: Update packages
  ((current_step++))
  show_progress $current_step $total_steps
  printf "\n"
  run_task "Updating package repositories" $PKG_UPDATE
  
  # Step 3: Install zram-tools
  ((current_step++))
  show_progress $current_step $total_steps
  printf "\n"
  run_task "Installing zram-tools package" $PKG_INSTALL zram-tools
  
  # Step 4: Ensure kernel modules
  ((current_step++))
  show_progress $current_step $total_steps
  printf "\n"
  KERNEL_VERSION=$(uname -r)
  case "$DISTRO_TYPE" in
    "debian")
      MODULE_PKG="linux-modules-extra-${KERNEL_VERSION}"
      run_task "Installing kernel modules (${MODULE_PKG})" $PKG_INSTALL "$MODULE_PKG"
      ;;
    "fedora")
      MODULE_PKG="kernel-modules-${KERNEL_VERSION}"
      run_task "Installing kernel modules (${MODULE_PKG})" $PKG_INSTALL "$MODULE_PKG"
      ;;
    "arch")
      run_task "Verifying kernel modules (Arch)" echo "Modules included with kernel"
      ;;
  esac
  
  # Step 5: Configure ZRAM
  ((current_step++))
  show_progress $current_step $total_steps
  printf "\n"
  
  # Backup existing config
  if [[ -f /etc/default/zramswap ]]; then
    run_task "Backing up existing configuration" cp /etc/default/zramswap{,.orig}
  fi
  
  # Write new config
  run_task "Writing ZRAM configuration" bash -c "cat > /etc/default/zramswap <<EOF
# ZRAM Configuration - Generated by ZRAM Quick Setup
# $(date)

ALGO=${ZRAM_ALGO}
PERCENT=${ZRAM_PERCENT}
PRIORITY=${ZRAM_PRIORITY}
EOF
"
  
  # Step 6: Start service
  ((current_step++))
  show_progress $current_step $total_steps
  printf "\n"
  detect_service
  run_task "Activating ZRAM service (${SERVICE_NAME})" systemctl restart "${SERVICE_NAME}.service"
  
  # Complete progress
  show_progress $total_steps $total_steps
  printf "\n\n"
}

# --- Enhanced final summary ---
show_final_summary() {
  echo -e "${C_GREEN}╔═══════════════════════════════════════════════════════════╗${C_NC}"
  echo -e "${C_GREEN}║ ${ICON_OK} ${C_BOLD}ZRAM SETUP COMPLETED SUCCESSFULLY!${C_NC}${C_GREEN}                ║${C_NC}"
  echo -e "${C_GREEN}╚═══════════════════════════════════════════════════════════╝${C_NC}"
  echo
  
  # Get swap information
  SWAP_INFO=$(swapon --show=NAME,SIZE,PRIO --bytes 2>/dev/null | grep zram || true)
  
  if [[ -z "$SWAP_INFO" ]]; then
    echo -e "${C_RED}╭─────────────────────────────────────╮${C_NC}"
    echo -e "${C_RED}│ ${ICON_FAIL} ${C_BOLD}ZRAM DEVICE NOT DETECTED${C_NC}${C_RED}     │${C_NC}"
    echo -e "${C_RED}╰─────────────────────────────────────╯${C_NC}"
    echo -e "${C_YELLOW}${ICON_INFO}Try running: ${C_GREEN}sudo systemctl status ${SERVICE_NAME}${C_NC}"
    exit 1
  fi

  # Parse swap info
  local name size prio
  IFS=$'\n' read -r name size prio <<<"$(awk '{print $1,$2,$3}' <<<"$SWAP_INFO")"
  
  # Convert bytes to human readable if needed
  if [[ $size =~ ^[0-9]+$ ]]; then
    size=$(numfmt --to=iec --suffix=B $size)
  fi
  
  # Professional results table
  echo -e "${C_HEADER}╭─────────────────────────────────────────────────────────╮${C_NC}"
  echo -e "${C_HEADER}│                    ${C_BOLD}ZRAM STATISTICS${C_NC}${C_HEADER}                      │${C_NC}"
  echo -e "${C_HEADER}╰─────────────────────────────────────────────────────────╯${C_NC}"
  echo
  printf "${C_BLUE}%-20s${C_NC} ${C_GRAY}│${C_NC} ${C_GREEN}%-25s${C_NC}\n" "${ICON_MEMORY}Device Name" "$name"
  printf "${C_BLUE}%-20s${C_NC} ${C_GRAY}│${C_NC} ${C_GREEN}%-25s${C_NC}\n" "${ICON_SPEED}Allocated Size" "$size"
  printf "${C_BLUE}%-20s${C_NC} ${C_GRAY}│${C_NC} ${C_GREEN}%-25s${C_NC}\n" "${ICON_GEAR}Swap Priority" "$prio"
  printf "${C_BLUE}%-20s${C_NC} ${C_GRAY}│${C_NC} ${C_GREEN}%-25s${C_NC}\n" "${ICON_SETUP}Algorithm" "$ZRAM_ALGO"
  printf "${C_BLUE}%-20s${C_NC} ${C_GRAY}│${C_NC} ${C_GREEN}%-25s${C_NC}\n" "${ICON_INFO}RAM Percentage" "${ZRAM_PERCENT}%"
  echo
  
  # Performance tips
  echo -e "${C_YELLOW}╭─────────────────────────────────────────────────────────╮${C_NC}"
  echo -e "${C_YELLOW}│                   ${C_BOLD}PERFORMANCE TIPS${C_NC}${C_YELLOW}                      │${C_NC}"
  echo -e "${C_YELLOW}╰─────────────────────────────────────────────────────────╯${C_NC}"
  echo -e "${C_GRAY}• Monitor with: ${C_GREEN}swapon --show${C_NC}"
  echo -e "${C_GRAY}• Check status: ${C_GREEN}sudo systemctl status ${SERVICE_NAME}${C_NC}"
  echo -e "${C_GRAY}• View stats:   ${C_GREEN}cat /proc/swaps${C_NC}"
  echo
  
  # Success footer
  echo -e "${C_GREEN}${ICON_ROCKET}${C_BOLD} ZRAM is now active and optimizing your system performance!${C_NC}"
  echo -e "${C_DIM}───────────────────────────────────────────────────────────${C_NC}"
}

# --- Error handler ---
error_handler() {
  echo
  echo -e "${C_RED}╭─────────────────────────────────────╮${C_NC}"
  echo -e "${C_RED}│ ${ICON_FAIL} ${C_BOLD}SETUP INTERRUPTED${C_NC}${C_RED}            │${C_NC}"
  echo -e "${C_RED}╰─────────────────────────────────────╯${C_NC}"
  echo -e "${C_YELLOW}${ICON_INFO}Check the logs above for details.${C_NC}"
  exit 1
}

# --- Set error handler ---
trap error_handler ERR INT TERM

# --- Execute main function ---
main
show_final_summary
