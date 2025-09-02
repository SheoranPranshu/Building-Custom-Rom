#!/usr/bin/env bash
# (your original header/comment lines kept)
set -eo pipefail

# --- Defaults ---
ZRAM_PERCENT=69
ZRAM_ALGO=zstd
ZRAM_PRIORITY=100

# --- Colors & Styles ---
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

# --- Icons ---
ICON_ZRAM="⚡"
ICON_OK="✓"
ICON_FAIL="✗"
ICON_ARROW="▶"
ICON_DOT="●"
ICON_MEMORY="🧠"
ICON_SPEED="🚀"
ICON_GEAR="⚙"

# --- Usage (kept) ---
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
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# --- Root check ---
if (( EUID != 0 )); then
  echo -e "${C_RED}${ICON_FAIL} ${C_BOLD}Root access required${C_NC} ${C_DIM}→ Run with sudo${C_NC}"
  exit 1
fi

# --- Temp logfile & cleanup ---
LOGFILE=$(mktemp /tmp/zram_setup.XXXXXX)
trap 'rm -f "$LOGFILE"' EXIT

# --- Detect package manager & service names ---
detect_system() {
  if command -v apt-get &>/dev/null; then
    PKG_INSTALL="apt-get install -y"
    PKG_UPDATE="apt-get update -y"
    DISTRO="debian"
  elif command -v dnf &>/dev/null; then
    PKG_INSTALL="dnf install -y"
    PKG_UPDATE="dnf check-update -y"
    DISTRO="fedora"
  elif command -v pacman &>/dev/null; then
    PKG_INSTALL="pacman -S --noconfirm"
    PKG_UPDATE="pacman -Sy"
    DISTRO="arch"
  else
    echo -e "${C_RED}${ICON_FAIL} Unsupported distribution${C_NC}"
    exit 1
  fi

  # Common service unit name candidates across images/cloud providers
  SERVICE_CANDIDATES=(zramswap zram zram-swap zram-config)

  # If systemctl exists, try to find a registered unit from the candidate list
  if command -v systemctl &>/dev/null; then
    for c in "${SERVICE_CANDIDATES[@]}"; do
      if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${c}.service"; then
        SERVICE_NAME="$c"
        return 0
      fi
    done

    # last attempt: check if any candidate returns a meaningful status (some distros don't register unit-files)
    for c in "${SERVICE_CANDIDATES[@]}"; do
      if systemctl status "${c}.service" &>/dev/null || systemctl status "${c}.service" &>/dev/null; then
        SERVICE_NAME="$c"
        return 0
      fi
    done
  fi

  # If we reach here, we couldn't detect a registered unit. leave SERVICE_NAME empty
  SERVICE_NAME=""
}

# --- Header & info ---
print_header() {
  echo -e "${C_CYAN}╭──────────────────────────────────────────────────────────╮${C_NC}"
  echo -e "${C_CYAN}│ ${ICON_ZRAM} ${C_BOLD}ZRAM SETUP${C_NC} ${C_BLUE}${ICON_SPEED} aka Memory Detonator${C_NC} ${C_CYAN}│${C_NC}"
  echo -e "${C_CYAN}╰──────────────────────────────────────────────────────────╯${C_NC}"
}

show_system_info() {
  local total_ram human_total
  human_total=$(free -h | awk '/^Mem:/ {print $2}')
  total_ram=$(free -b | awk '/^Mem:/ {print $2}')
  local kernel=$(uname -r)
  local distro=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 | head -1)

  echo -e "${C_PURPLE}${ICON_MEMORY} System:${C_NC} ${distro} ${C_DIM}|${C_NC} ${C_BLUE}Kernel:${C_NC} ${kernel} ${C_DIM}|${C_NC} ${C_GREEN}RAM:${C_NC} ${human_total}"
  if [[ -n "${SERVICE_NAME}" ]]; then
    echo -e "${C_ORANGE}${ICON_GEAR} Detected service:${C_NC} ${SERVICE_NAME}.service"
  else
    echo -e "${C_ORANGE}${ICON_GEAR} Detected service:${C_NC} ${C_YELLOW}none auto-detected (will try common names)${C_NC}"
  fi
  echo -e "${C_ORANGE}${ICON_GEAR} Config:${C_NC} ${ZRAM_PERCENT}% RAM, ${ZRAM_ALGO} compression, priority ${ZRAM_PRIORITY}"
}

show_current_memory() {
  local total used avail
  total=$(free -h | awk '/^Mem:/ {print $2}')
  used=$(free -h | awk '/^Mem:/ {print $3}')
  avail=$(free -h | awk '/^Mem:/ {print $7}')
  echo -e "${C_BOLD}${ICON_MEMORY} Current Memory:${C_NC} ${C_GREEN}${total}${C_NC} ${C_DIM}(${used} used, ${avail} available)${C_NC}"

  local swaps
  swaps=$(swapon --show --noheadings 2>/dev/null || true)
  if [[ -n "$swaps" ]]; then
    echo -e "${C_BOLD}${ICON_DOT} Existing Swap:${C_NC}"
    echo -e "${C_DIM}${swaps}${C_NC}"
  else
    echo -e "${C_BOLD}${ICON_DOT} Existing Swap:${C_NC} ${C_DIM}None${C_NC}"
  fi
}

# --- Task runner (clean spinner) ---
run_task(){
  local msg=$1; shift
  printf "${C_BLUE}${ICON_ARROW}${C_NC} %-40s ${C_DIM}[${C_NC}" "$msg"

  "$@" &> "$LOGFILE" &
  local pid=$!
  local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\b${C_CYAN}${spinner[i++ % ${#spinner[@]}]}${C_DIM}]${C_NC}"
    sleep 0.08
  done

  if wait "$pid"; then
    printf "\b${C_GREEN}${ICON_OK}${C_DIM}]${C_NC}\n"
  else
    printf "\b${C_RED}${ICON_FAIL}${C_DIM}]${C_NC}\n"
    echo -e "${C_RED}${ICON_FAIL} Error (see log):${C_NC}" >&2
    sed 's/^/  /' "$LOGFILE" >&2
    exit 1
  fi
}

# --- Try service action across candidates (uses run_task so logs/spinner shown) ---
service_action_try() {
  local action=$1
  local label="$action"
  # if we detected a specific service name, prefer it
  if [[ -n "${SERVICE_NAME}" ]]; then
    run_task "${label^} ${SERVICE_NAME}.service" systemctl "${action}" "${SERVICE_NAME}.service"
    return $?
  fi

  # otherwise try each candidate in order until one succeeds
  local cmd
  cmd="set -e; "
  for c in "${SERVICE_CANDIDATES[@]}"; do
    # try and return when the first one succeeds
    cmd+="(systemctl ${action} ${c}.service && echo '${c}' && exit 0) || true; "
  done
  # if none succeed, try the older 'service' interface as last resort (best-effort)
  cmd+="(command -v service >/dev/null 2>&1 && { service ${SERVICE_CANDIDATES[0]} ${action} >/dev/null 2>&1 || true; } ); exit 1"

  run_task "${label^} (best-effort candidates)" bash -c "$cmd" || {
    echo -e "${C_YELLOW}${ICON_FAIL} Warning:${C_NC} Could not ${action} any known zram service unit. ${C_DIM}You may need to start the service manually.${C_NC}"
  }
}

# --- Main flow ---
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

  # Kernel modules (best-effort)
  KERNEL_VERSION=$(uname -r)
  case "$DISTRO" in
    debian) run_task "Ensuring kernel modules" $PKG_INSTALL "linux-modules-extra-${KERNEL_VERSION}" || true ;;
    fedora) run_task "Ensuring kernel modules" $PKG_INSTALL "kernel-modules-${KERNEL_VERSION}" || true ;;
    arch)   run_task "Verifying kernel support" bash -c "echo 'Kernel support assumed'";;
  esac

  # Backup existing config
  if [[ -f /etc/default/zramswap ]]; then
    run_task "Backing up old config" cp /etc/default/zramswap{,.backup}
  fi

  # Write config atomically
  run_task "Writing ZRAM config" bash -c "cat > /etc/default/zramswap.tmp <<EOF
ALGO=${ZRAM_ALGO}
PERCENT=${ZRAM_PERCENT}
PRIORITY=${ZRAM_PRIORITY}
EOF
mv /etc/default/zramswap.tmp /etc/default/zramswap"

  # Start/restart + enable at boot (use detection / best-effort)
  service_action_try restart
  service_action_try enable

  echo
  show_final_summary
}

# --- Final summary ---
show_final_summary() {
  echo -e "${C_GREEN}${ICON_OK} ${C_BOLD}ZRAM Setup Complete!${C_NC}"
  echo

  local phys_total phys_used phys_avail
  phys_total=$(free -h | awk '/^Mem:/ {print $2}')
  phys_used=$(free -h | awk '/^Mem:/ {print $3}')
  phys_avail=$(free -h | awk '/^Mem:/ {print $7}')

  echo -e "${C_BOLD}${ICON_MEMORY} Memory Summary:${C_NC}"
  echo -e "${C_BLUE}  Physical RAM:${C_NC} ${C_GREEN}${phys_total}${C_NC} ${C_DIM}(${phys_used} used, ${phys_avail} available)${C_NC}"

  local zinfo
  zinfo=$(swapon --show --noheadings 2>/dev/null | grep -m1 zram || true)
  if [[ -n "$zinfo" ]]; then
    local zdev zsize zprio
    zdev=$(echo "$zinfo" | awk '{print $1}')
    zsize=$(echo "$zinfo" | awk '{print $2}')
    zprio=$(echo "$zinfo" | awk '{print $4}')
    echo -e "${C_PURPLE}  ZRAM Swap:${C_NC} ${C_GREEN}${zsize}${C_NC} ${C_DIM}(${zdev}, prio ${zprio})${C_NC}"

    # compression ratio (best-effort)
    if [[ -r /sys/block/zram0/mm_stat ]]; then
      read -r orig comp <<<"$(awk '{print $1, $2}' /sys/block/zram0/mm_stat 2>/dev/null || echo "0 0")"
      if [[ $comp -gt 0 && $orig -gt 0 ]]; then
        local ratio
        ratio=$(awk "BEGIN {printf \"%.2f\", $orig/$comp}")
        echo -e "${C_ORANGE}  Compression:${C_NC} ${C_YELLOW}${ratio}:1${C_NC} ${C_DIM}(${ZRAM_ALGO})${C_NC}"
      fi
    fi

    # effective memory (approx)
    local phys_g z_g total_eff
    phys_g=$(free -g | awk '/^Mem:/ {print $2}')
    z_g=$(echo "$zsize" | sed -E 's/([0-9]+).*/\1/')
    total_eff=$((phys_g + z_g))
    echo -e "${C_CYAN}  Effective RAM:${C_NC} ${C_BOLD}~${total_eff}GB${C_NC} ${C_DIM}(approx)${C_NC}"
  else
    echo -e "${C_RED}  ${ICON_FAIL} ZRAM not detected.${C_NC}"
  fi

  echo
  echo -e "${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
  echo -e "${C_BOLD}Quick Commands:${C_NC} ${C_DIM}status:${C_NC} ${C_GREEN}systemctl status ${SERVICE_NAME:-<zramswap|zram|zram-swap>} ${C_NC} ${C_DIM}| check:${C_NC} ${C_GREEN}swapon --show${C_NC} ${C_DIM}| stats:${C_NC} ${C_GREEN}cat /proc/swaps${C_NC}"
  echo
}

# --- Interrupt handling ---
trap 'echo -e "\n${C_RED}${ICON_FAIL} Interrupted${C_NC}"; exit 1' INT TERM

# --- Run ---
main "$@"
