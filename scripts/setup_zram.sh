#!/usr/bin/env bash

#
# ZRAM Configuration Script
# Usage: sudo ./setup_zram.sh [-p percent] [-a algo] [-r priority] [-h]
#

set -e

ZRAM_PERCENT=69
ZRAM_ALGO=zstd
ZRAM_PRIORITY=100

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

usage(){
    echo -e "${C_BOLD}Usage:${C_NC} sudo $0 [options]"
    echo -e "${C_YELLOW}  -p${C_NC} PERCENT  ${C_DIM}ZRAM size percentage (default: ${ZRAM_PERCENT})${C_NC}"
    echo -e "${C_YELLOW}  -a${C_NC} ALGO     ${C_DIM}Compression algorithm (default: ${ZRAM_ALGO})${C_NC}"
    echo -e "${C_YELLOW}  -r${C_NC} PRIORITY ${C_DIM}Swap priority (default: ${ZRAM_PRIORITY})${C_NC}"
    echo -e "${C_YELLOW}  -h${C_NC}          ${C_DIM}Display help${C_NC}"
}

while getopts "p:a:r:h" opt; do
    case $opt in
        p) ZRAM_PERCENT=$OPTARG ;;
        a) ZRAM_ALGO=$OPTARG   ;;
        r) ZRAM_PRIORITY=$OPTARG ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

if (( EUID != 0 )); then
    echo -e "${C_RED}[ERROR]${C_NC} Root privileges required. Run with sudo."
    exit 1
fi

SERVICE_CANDIDATES=(zramswap zram zram-swap zram-config)
SERVICE_NAME=""

detect_system() {
    if command -v apt-get &>/dev/null; then
        PKG_INSTALL="apt-get install -y"
        PKG_UPDATE="apt-get update"
        DISTRO="debian"
    elif command -v dnf &>/dev/null; then
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf check-update"
        DISTRO="fedora"
    elif command -v pacman &>/dev/null; then
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE="pacman -Sy"
        DISTRO="arch"
    else
        echo -e "${C_RED}[ERROR]${C_NC} Unsupported distribution"
        exit 1
    fi
}

print_status() {
    echo -e "${C_BLUE}[INFO]${C_NC} $1"
}

print_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"
}

print_warning() {
    echo -e "${C_YELLOW}[WARNING]${C_NC} $1"
}

print_error() {
    echo -e "${C_RED}[ERROR]${C_NC} $1" >&2
}

print_header() {
    echo -e "${C_CYAN}========================================${C_NC}"
    echo -e "${C_CYAN} ZRAM Configuration System${C_NC}"
    echo -e "${C_CYAN}========================================${C_NC}"
}

show_system_info() {
    local human_total kernel distro
    human_total=$(free -h | awk '/^Mem:/ {print $2}')
    kernel=$(uname -r)
    distro=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 | head -1)

    print_status "System: ${distro}"
    print_status "Kernel: ${kernel}"
    print_status "Total RAM: ${human_total}"
    if [[ -n "${SERVICE_NAME}" ]]; then
        print_status "Detected service: ${SERVICE_NAME}.service"
    fi
    print_status "Configuration: ${ZRAM_PERCENT}% RAM, ${ZRAM_ALGO} compression, priority ${ZRAM_PRIORITY}"
}

show_current_memory() {
    local total used avail swaps
    total=$(free -h | awk '/^Mem:/ {print $2}')
    used=$(free -h | awk '/^Mem:/ {print $3}')
    avail=$(free -h | awk '/^Mem:/ {print $7}')
    
    echo -e "${C_BOLD}Current Memory Status:${C_NC}"
    echo -e "  Physical Memory: ${C_GREEN}${total}${C_NC} (${used} used, ${avail} available)"

    swaps=$(swapon --show --noheadings 2>/dev/null || true)
    if [[ -n "$swaps" ]]; then
        echo -e "  Existing Swap Configuration:"
        echo -e "${C_DIM}${swaps}${C_NC}"
    else
        echo -e "  Existing Swap: None configured"
    fi
}

run_task(){
    local msg=$1; shift
    printf "${C_BLUE}[TASK]${C_NC} %-50s " "$msg"

    if "$@"; then
        printf "${C_GREEN}[OK]${C_NC}\n"
    else
        printf "${C_RED}[FAILED]${C_NC}\n"
        print_error "Task failed: $msg"
        exit 1
    fi
}

service_action_try() {
    local action=$1
    local label="$action"

    if [[ -n "${SERVICE_NAME}" ]]; then
        run_task "${label^} ${SERVICE_NAME}.service" systemctl "${action}" "${SERVICE_NAME}.service"
        return $?
    fi

    for c in "${SERVICE_CANDIDATES[@]}"; do
        if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${c}.service"; then
            SERVICE_NAME="$c"
            print_success "Using service: ${SERVICE_NAME}.service"
            run_task "${label^} ${SERVICE_NAME}.service" systemctl "${action}" "${SERVICE_NAME}.service"
            return $?
        fi
    done

    for c in "${SERVICE_CANDIDATES[@]}"; do
        if service "${c}" status >/dev/null 2>&1; then
            SERVICE_NAME="$c"
            print_success "Using legacy service: ${SERVICE_NAME}"
            run_task "${label^} ${SERVICE_NAME}" service "${SERVICE_NAME}" "${action}"
            return 0
        fi
    done

    print_warning "No known ZRAM service found to ${action}"
    return 1
}

main() {
    clear
    print_header

    detect_system
    show_system_info
    echo
    show_current_memory
    echo

    print_status "Beginning ZRAM installation and configuration"
    
    run_task "Updating package repositories" $PKG_UPDATE
    run_task "Installing zram-tools package" $PKG_INSTALL zram-tools

    KERNEL_VERSION=$(uname -r)
    case "$DISTRO" in
        debian) 
            run_task "Installing kernel modules" $PKG_INSTALL "linux-modules-extra-${KERNEL_VERSION}" || print_warning "Kernel modules installation failed, continuing"
            ;;
        fedora) 
            run_task "Installing kernel modules" $PKG_INSTALL "kernel-modules-${KERNEL_VERSION}" || print_warning "Kernel modules installation failed, continuing"
            ;;
        arch)   
            print_status "Assuming kernel support is available for Arch Linux"
            ;;
    esac

    if [[ -f /etc/default/zramswap ]]; then
        run_task "Creating backup of existing configuration" cp /etc/default/zramswap{,.backup}
    fi

    run_task "Writing ZRAM configuration" bash -c "cat > /etc/default/zramswap <<EOF
ALGO=${ZRAM_ALGO}
PERCENT=${ZRAM_PERCENT}
PRIORITY=${ZRAM_PRIORITY}
EOF"

    service_action_try restart
    service_action_try enable

    echo
    show_final_summary
}

show_final_summary() {
    print_success "ZRAM configuration completed successfully"
    echo

    local phys_total phys_used phys_avail
    phys_total=$(free -h | awk '/^Mem:/ {print $2}')
    phys_used=$(free -h | awk '/^Mem:/ {print $3}')
    phys_avail=$(free -h | awk '/^Mem:/ {print $7}')

    echo -e "${C_BOLD}System Memory Status:${C_NC}"
    echo -e "  Physical RAM: ${C_GREEN}${phys_total}${C_NC} (${phys_used} used, ${phys_avail} available)"

    local zinfo
    zinfo=$(swapon --show --noheadings 2>/dev/null | grep -m1 zram || true)
    if [[ -n "$zinfo" ]]; then
        local zdev zsize zprio
        zdev=$(echo "$zinfo" | awk '{print $1}')
        zsize=$(echo "$zinfo" | awk '{print $2}')
        zprio=$(echo "$zinfo" | awk '{print $4}')
        echo -e "  ZRAM Swap: ${C_GREEN}${zsize}${C_NC} (${zdev}, priority ${zprio})"

        if [[ -r /sys/block/zram0/mm_stat ]]; then
            read -r orig comp <<<"$(awk '{print $1, $2}' /sys/block/zram0/mm_stat 2>/dev/null || echo "0 0")"
            if [[ $comp -gt 0 && $orig -gt 0 ]]; then
                local ratio
                ratio=$(awk "BEGIN {printf \"%.2f\", $orig/$comp}")
                echo -e "  Compression Ratio: ${C_YELLOW}${ratio}:1${C_NC} (${ZRAM_ALGO})"
            fi
        fi

        local phys_g z_g total_eff
        phys_g=$(free -g | awk '/^Mem:/ {print $2}')
        z_g=$(echo "$zsize" | sed -E 's/([0-9]+).*/\1/')
        total_eff=$((phys_g + z_g))
        echo -e "  Effective Memory: ${C_BOLD}~${total_eff}GB${C_NC} (approximate)"
    else
        print_error "ZRAM swap not detected after configuration"
    fi

    echo
    echo -e "${C_DIM}========================================${C_NC}"
    echo -e "${C_BOLD}Management Commands:${C_NC}"
    echo -e "  Service Status: ${C_GREEN}systemctl status ${SERVICE_NAME:-zramswap}${C_NC}"
    echo -e "  Swap Status: ${C_GREEN}swapon --show${C_NC}"
    echo -e "  Memory Statistics: ${C_GREEN}cat /proc/swaps${C_NC}"
    echo
}

trap 'echo -e "\n${C_RED}[ERROR]${C_NC} Operation interrupted"; exit 1' INT TERM

main "$@"
