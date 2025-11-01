#!/usr/bin/env bash

#
# Usage: sudo ./setup_zram.sh [-p percent] [-a algo] [-r priority] [-h]
#

set -eo pipefail

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

if [[ $EUID -ne 0 ]]; then
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
        PKG_UPDATE="dnf check-update || true"
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

print_status() { echo -e "${C_BLUE}[INFO]${C_NC} $1"; }
print_success() { echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"; }
print_warning() { echo -e "${C_YELLOW}[WARNING]${C_NC} $1"; }
print_error() { echo -e "${C_RED}[ERROR]${C_NC} $1" >&2; }

print_header() {
    echo -e "${C_CYAN}========================================${C_NC}"
    echo -e "${C_CYAN} ZRAM Configuration System${C_NC}"
    echo -e "${C_CYAN}========================================${C_NC}"
}

show_system_info() {
    local human_total=$(free -h | awk '/^Mem:/ {print $2}')
    local kernel=$(uname -r)
    local distro=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 | head -1)

    print_status "System: ${distro}"
    print_status "Kernel: ${kernel}"
    print_status "Total RAM: ${human_total}"
    [[ -n "${SERVICE_NAME}" ]] && print_status "Detected service: ${SERVICE_NAME}.service"
    print_status "Configuration: ${ZRAM_PERCENT}% RAM, ${ZRAM_ALGO} compression, priority ${ZRAM_PRIORITY}"
}

show_current_memory() {
    local total=$(free -h | awk '/^Mem:/ {print $2}')
    local used=$(free -h | awk '/^Mem:/ {print $3}')
    local avail=$(free -h | awk '/^Mem:/ {print $7}')
    
    echo -e "${C_BOLD}Current Memory Status:${C_NC}"
    echo -e "  Physical Memory: ${C_GREEN}${total}${C_NC} (${used} used, ${avail} available)"

    local swaps=$(swapon --show --noheadings 2>/dev/null || true)
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

    if "$@" &>/dev/null; then
        printf "${C_GREEN}[OK]${C_NC}\n"
    else
        printf "${C_RED}[FAILED]${C_NC}\n"
        print_error "Task failed: $msg"
        exit 1
    fi
}

detect_service() {
    for c in "${SERVICE_CANDIDATES[@]}"; do
        if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${c}.service"; then
            SERVICE_NAME="$c"
            return 0
        fi
    done
    
    for c in "${SERVICE_CANDIDATES[@]}"; do
        if service "${c}" status &>/dev/null; then
            SERVICE_NAME="$c"
            return 0
        fi
    done
    
    return 1
}

service_action() {
    local action=$1
    
    if [[ -z "${SERVICE_NAME}" ]] && ! detect_service; then
        print_warning "No ZRAM service found to ${action}"
        return 1
    fi
    
    if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${SERVICE_NAME}.service"; then
        run_task "${action^} ${SERVICE_NAME}.service" systemctl "${action}" "${SERVICE_NAME}.service"
    else
        run_task "${action^} ${SERVICE_NAME}" service "${SERVICE_NAME}" "${action}"
    fi
}

configure_kernel_params() {
    local sysctl_conf="/etc/sysctl.d/99-zram.conf"
    
    cat > "$sysctl_conf" <<EOF
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
    
    sysctl -p "$sysctl_conf" &>/dev/null
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

    case "$DISTRO" in
        debian|fedora) 
            local kernel_pkg
            [[ "$DISTRO" == "debian" ]] && kernel_pkg="linux-modules-extra-$(uname -r)" || kernel_pkg="kernel-modules-$(uname -r)"
            $PKG_INSTALL "$kernel_pkg" &>/dev/null || print_warning "Kernel modules installation failed, continuing"
            ;;
    esac

    [[ -f /etc/default/zramswap ]] && run_task "Creating backup of existing configuration" cp /etc/default/zramswap{,.backup-$(date +%Y%m%d-%H%M%S)}

    run_task "Writing ZRAM configuration" bash -c "cat > /etc/default/zramswap <<EOF
ALGO=${ZRAM_ALGO}
PERCENT=${ZRAM_PERCENT}
PRIORITY=${ZRAM_PRIORITY}
EOF"

    run_task "Configuring kernel parameters" configure_kernel_params
    
    service_action restart
    service_action enable

    echo
    show_final_summary
}

show_final_summary() {
    print_success "ZRAM configuration completed successfully"
    echo

    local phys_total=$(free -h | awk '/^Mem:/ {print $2}')
    local phys_used=$(free -h | awk '/^Mem:/ {print $3}')
    local phys_avail=$(free -h | awk '/^Mem:/ {print $7}')

    echo -e "${C_BOLD}System Memory Status:${C_NC}"
    echo -e "  Physical RAM: ${C_GREEN}${phys_total}${C_NC} (${phys_used} used, ${phys_avail} available)"

    local zinfo=$(swapon --show --noheadings 2>/dev/null | grep -m1 zram || true)
    if [[ -n "$zinfo" ]]; then
        local zdev=$(echo "$zinfo" | awk '{print $1}')
        local zsize=$(echo "$zinfo" | awk '{print $2}')
        local zprio=$(echo "$zinfo" | awk '{print $4}')
        echo -e "  ZRAM Swap: ${C_GREEN}${zsize}${C_NC} (${zdev}, priority ${zprio})"

        if [[ -r /sys/block/zram0/mm_stat ]]; then
            local orig comp
            read -r orig comp _ < /sys/block/zram0/mm_stat 2>/dev/null || { orig=0; comp=0; }
            if [[ $comp -gt 0 && $orig -gt 0 ]]; then
                local ratio=$(awk "BEGIN {printf \"%.2f\", $orig/$comp}")
                echo -e "  Compression Ratio: ${C_YELLOW}${ratio}:1${C_NC} (${ZRAM_ALGO})"
            fi
        fi

        local phys_g=$(free -g | awk '/^Mem:/ {print $2}')
        local z_g=$(echo "$zsize" | grep -oE '[0-9]+' | head -1)
        local total_eff=$((phys_g + z_g))
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
    echo -e "  Kernel Parameters: ${C_GREEN}cat /etc/sysctl.d/99-zram.conf${C_NC}"
    echo
}

trap 'echo -e "\n${C_RED}[ERROR]${C_NC} Operation interrupted"; exit 1' INT TERM

main "$@"
