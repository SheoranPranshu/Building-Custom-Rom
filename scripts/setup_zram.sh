#!/usr/bin/env bash
# Usage: sudo ./setup_zram.sh [-p percent] [-a algo] [-r priority] [-h]

set -eo pipefail

# Default configuration values
readonly DEFAULT_ZRAM_PERCENT=69
readonly DEFAULT_ZRAM_ALGO="zstd"
readonly DEFAULT_ZRAM_PRIORITY=100

ZRAM_PERCENT="${DEFAULT_ZRAM_PERCENT}"
ZRAM_ALGO="${DEFAULT_ZRAM_ALGO}"
ZRAM_PRIORITY="${DEFAULT_ZRAM_PRIORITY}"

# Color definitions - using tput for better terminal compatibility
if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    C_BOLD=$(tput bold)
    C_DIM=$(tput dim)
    C_NC=$(tput sgr0)
    C_RED=$(tput setaf 1)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_BLUE=$(tput setaf 4)
    C_PURPLE=$(tput setaf 5)
    C_CYAN=$(tput setaf 6)
    C_ORANGE=$(tput setaf 208 2>/dev/null || tput setaf 3)
else
    C_BOLD="" C_DIM="" C_NC=""
    C_RED="" C_GREEN="" C_YELLOW=""
    C_BLUE="" C_PURPLE="" C_CYAN="" C_ORANGE=""
fi

# Service detection array
readonly SERVICE_CANDIDATES=("zramswap" "zram" "zram-swap" "zram-config")
SERVICE_NAME=""

# Package manager variables
PKG_INSTALL=""
PKG_UPDATE=""
DISTRO=""

# Display usage information
usage() {
    cat <<EOF
${C_BOLD}Usage:${C_NC} sudo $0 [options]

${C_BOLD}Options:${C_NC}
  ${C_YELLOW}-p${C_NC} PERCENT  ZRAM size percentage (default: ${DEFAULT_ZRAM_PERCENT})
  ${C_YELLOW}-a${C_NC} ALGO     Compression algorithm (default: ${DEFAULT_ZRAM_ALGO})
  ${C_YELLOW}-r${C_NC} PRIORITY Swap priority (default: ${DEFAULT_ZRAM_PRIORITY})
  ${C_YELLOW}-h${C_NC}          Display this help message

${C_BOLD}Examples:${C_NC}
  sudo $0                    # Use defaults
  sudo $0 -p 50 -a lz4       # 50% RAM with lz4 compression
  sudo $0 -r 200             # Set priority to 200

EOF
}

# Parse command line arguments
parse_arguments() {
    while getopts "p:a:r:h" opt; do
        case "${opt}" in
            p)
                if [[ "${OPTARG}" =~ ^[0-9]+$ ]] && [ "${OPTARG}" -gt 0 ] && [ "${OPTARG}" -le 100 ]; then
                    ZRAM_PERCENT="${OPTARG}"
                else
                    print_error "Invalid percentage: ${OPTARG} (must be 1-100)"
                    exit 1
                fi
                ;;
            a) ZRAM_ALGO="${OPTARG}" ;;
            r)
                if [[ "${OPTARG}" =~ ^[0-9]+$ ]]; then
                    ZRAM_PRIORITY="${OPTARG}"
                else
                    print_error "Invalid priority: ${OPTARG} (must be numeric)"
                    exit 1
                fi
                ;;
            h) usage; exit 0 ;;
            *) usage; exit 1 ;;
        esac
    done
}

# Check for root privileges
check_root() {
    if [ "${EUID}" -ne 0 ]; then
        print_error "Root privileges required. Please run with sudo."
        exit 1
    fi
}

# Detect Linux distribution and set package manager
detect_system() {
    # Try to detect via os-release first (most reliable)
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        local id="${ID,,}"  # Convert to lowercase
        local id_like="${ID_LIKE,,}"
    fi

    # Set package manager based on distro
    if command -v apt-get >/dev/null 2>&1; then
        PKG_INSTALL="apt-get install -y"
        PKG_UPDATE="apt-get update"
        DISTRO="debian"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf check-update || true"
        DISTRO="fedora"
    elif command -v yum >/dev/null 2>&1; then
        PKG_INSTALL="yum install -y"
        PKG_UPDATE="yum check-update || true"
        DISTRO="rhel"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_INSTALL="zypper install -y"
        PKG_UPDATE="zypper refresh"
        DISTRO="opensuse"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE="pacman -Sy"
        DISTRO="arch"
    elif command -v apk >/dev/null 2>&1; then
        PKG_INSTALL="apk add"
        PKG_UPDATE="apk update"
        DISTRO="alpine"
    else
        print_error "Unsupported distribution or package manager not found"
        exit 1
    fi
}

# Print functions with consistent formatting
print_status() {
    printf "%s[INFO]%s %s\n" "${C_BLUE}" "${C_NC}" "$1"
}

print_success() {
    printf "%s[✓]%s %s\n" "${C_GREEN}" "${C_NC}" "$1"
}

print_warning() {
    printf "%s[!]%s %s\n" "${C_YELLOW}" "${C_NC}" "$1"
}

print_error() {
    printf "%s[✗]%s %s\n" "${C_RED}" "${C_NC}" "$1" >&2
}

# Display header with better visual appeal
print_header() {
    local width=50
    printf "\n%s" "${C_CYAN}"
    printf "%${width}s\n" | tr ' ' '='
    printf "%*s\n" $(((width + 26) / 2)) "ZRAM Configuration System"
    printf "%${width}s\n" | tr ' ' '='
    printf "%s\n" "${C_NC}"
}

# Show system information
show_system_info() {
    local human_total kernel distro_name
    
    human_total=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    kernel=$(uname -r)
    
    # Get distribution name
    if [ -f /etc/os-release ]; then
        distro_name=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
    else
        distro_name="Unknown Linux"
    fi

    printf "\n%sSystem Information:%s\n" "${C_BOLD}" "${C_NC}"
    printf "  %-15s : %s\n" "Distribution" "${distro_name}"
    printf "  %-15s : %s\n" "Kernel" "${kernel}"
    printf "  %-15s : %s\n" "Total RAM" "${human_total}"
    
    [ -n "${SERVICE_NAME}" ] && printf "  %-15s : %s\n" "Service" "${SERVICE_NAME}.service"
    
    printf "\n%sConfiguration:%s\n" "${C_BOLD}" "${C_NC}"
    printf "  %-15s : %s%%\n" "ZRAM Size" "${ZRAM_PERCENT}"
    printf "  %-15s : %s\n" "Algorithm" "${ZRAM_ALGO}"
    printf "  %-15s : %s\n" "Priority" "${ZRAM_PRIORITY}"
}

# Display current memory status
show_current_memory() {
    local total used avail
    
    total=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    used=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3}')
    avail=$(free -h 2>/dev/null | awk '/^Mem:/ {print $7}')
    
    printf "\n%sCurrent Memory Status:%s\n" "${C_BOLD}" "${C_NC}"
    printf "  Physical RAM : %s%s%s (Used: %s, Available: %s)\n" \
           "${C_GREEN}" "${total}" "${C_NC}" "${used}" "${avail}"

    local swaps
    swaps=$(swapon --show --noheadings 2>/dev/null || true)
    
    if [ -n "${swaps}" ]; then
        printf "  Current Swap :\n"
        printf "%s%s%s\n" "${C_DIM}" "${swaps}" "${C_NC}" | sed 's/^/    /'
    else
        printf "  Current Swap : None configured\n"
    fi
}

# Execute task with status indicator
run_task() {
    local msg="$1"
    shift
    
    printf "  %-45s " "${msg}..."
    
    if "$@" >/dev/null 2>&1; then
        printf "%s[✓]%s\n" "${C_GREEN}" "${C_NC}"
        return 0
    else
        printf "%s[✗]%s\n" "${C_RED}" "${C_NC}"
        print_error "Task failed: ${msg}"
        return 1
    fi
}

# Detect existing ZRAM service
detect_service() {
    local candidate
    
    # Check systemd services
    if command -v systemctl >/dev/null 2>&1; then
        for candidate in "${SERVICE_CANDIDATES[@]}"; do
            if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${candidate}.service"; then
                SERVICE_NAME="${candidate}"
                return 0
            fi
        done
    fi
    
    # Check SysV/OpenRC services
    if command -v service >/dev/null 2>&1; then
        for candidate in "${SERVICE_CANDIDATES[@]}"; do
            if service "${candidate}" status >/dev/null 2>&1; then
                SERVICE_NAME="${candidate}"
                return 0
            fi
        done
    fi
    
    return 1
}

# Manage service actions (start/stop/enable/disable)
service_action() {
    local action="$1"
    local service_name=""
    local status=0
    
    if [ -z "${SERVICE_NAME}" ] && ! detect_service; then
        print_warning "No ZRAM service found to ${action}"
        return 1
    fi
    
    # Use systemctl if available
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${SERVICE_NAME}.service"; then
            service_name="${SERVICE_NAME}.service"
        else
            print_warning "Service ${SERVICE_NAME}.service not found in systemctl"
            return 1
        fi

        run_task "${action^} ${service_name}" systemctl "${action}" "${service_name}"
        # Check status after action
        if [ "${action}" = "restart" ] || [ "${action}" = "start" ]; then
            if ! systemctl is-active --quiet "${service_name}"; then
                print_error "Service ${service_name} is not active after ${action}"
                status=1
            fi
        fi
    # Fall back to service command
    elif command -v service >/dev/null 2>&1; then
        if [ -z "${SERVICE_NAME}" ]; then
            print_warning "No service name detected for service command"
            return 1
        fi

        run_task "${action^} ${SERVICE_NAME}" service "${SERVICE_NAME}" "${action}"
        # Check status after action (if we can)
        if [ "${action}" = "restart" ] || [ "${action}" = "start" ]; then
            if ! service "${SERVICE_NAME}" status >/dev/null 2>&1; then
                print_error "Service ${SERVICE_NAME} is not running after ${action}"
                status=1
            fi
        fi
    else
        print_warning "Could not ${action} service - no service manager found"
        return 1
    fi

    return ${status}
}

# Configure kernel parameters for optimal ZRAM performance
configure_kernel_params() {
    local sysctl_conf="/etc/sysctl.d/99-zram.conf"
    
    cat > "${sysctl_conf}" <<EOF
# ZRAM optimized kernel parameters
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
    
    sysctl -p "${sysctl_conf}" >/dev/null 2>&1
}

# Install distro-specific packages
install_packages() {
    run_task "Updating package repositories" ${PKG_UPDATE}
    
    # Install main package
    case "${DISTRO}" in
        debian|ubuntu)
            run_task "Installing zram-tools" ${PKG_INSTALL} zram-tools
            # Ubuntu-specific kernel and module installation
            run_task "Installing kernel and modules" ${PKG_INSTALL} linux-generic linux-modules-extra-$(uname -r)
            ;;
        fedora|rhel)
            run_task "Installing zram package" ${PKG_INSTALL} zram
            ;;
        opensuse)
            run_task "Installing systemd-zram-service" ${PKG_INSTALL} systemd-zram-service
            ;;
        arch)
            run_task "Installing zramswap" ${PKG_INSTALL} zramswap || \
            run_task "Installing from AUR" yay -S --noconfirm zramd 2>/dev/null || \
            print_warning "Please install a ZRAM package from AUR manually"
            ;;
        *)
            run_task "Installing zram-tools" ${PKG_INSTALL} zram-tools
            ;;
    esac
    
    # Load zram module
    run_task "Loading zram module" modprobe zram
}

# Configure ZRAM settings
configure_zram() {
    local config_file="/etc/default/zramswap"
    
    # Backup existing configuration
    if [ -f "${config_file}" ]; then
        local backup="${config_file}.backup-$(date +%Y%m%d-%H%M%S)"
        run_task "Backing up existing configuration" cp "${config_file}" "${backup}"
    fi
    
    # Write new configuration
    run_task "Writing ZRAM configuration" bash -c "cat > ${config_file} <<EOF
# ZRAM configuration
ALGO=${ZRAM_ALGO}
PERCENT=${ZRAM_PERCENT}
PRIORITY=${ZRAM_PRIORITY}
EOF"
}

# Display final summary with comprehensive information
show_final_summary() {
    local phys_total phys_used phys_avail zinfo zdev zsize zprio
    
    print_success "ZRAM configuration completed successfully!"
    printf "\n"
    
    # Get memory stats
    phys_total=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    phys_used=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3}')
    phys_avail=$(free -h 2>/dev/null | awk '/^Mem:/ {print $7}')
    
    printf "%sMemory Configuration:%s\n" "${C_BOLD}" "${C_NC}"
    printf "  Physical RAM : %s%s%s (Used: %s, Free: %s)\n" \
           "${C_GREEN}" "${phys_total}" "${C_NC}" "${phys_used}" "${phys_avail}"
    
    # Check ZRAM status
    zinfo=$(swapon --show --noheadings 2>/dev/null | grep -m1 zram || true)
    
    if [ -n "${zinfo}" ]; then
        zdev=$(echo "${zinfo}" | awk '{print $1}')
        zsize=$(echo "${zinfo}" | awk '{print $2}')
        zprio=$(echo "${zinfo}" | awk '{print $4}')
        
        printf "  ZRAM Swap    : %s%s%s (Device: %s, Priority: %s)\n" \
               "${C_GREEN}" "${zsize}" "${C_NC}" "${zdev}" "${zprio}"
        
        # Show compression stats if available
        if [ -r /sys/block/zram0/mm_stat ]; then
            local orig comp ratio
            read -r orig comp _ < /sys/block/zram0/mm_stat 2>/dev/null || true
            
            if [ "${comp:-0}" -gt 0 ] && [ "${orig:-0}" -gt 0 ]; then
                ratio=$(awk "BEGIN {printf \"%.2f\", ${orig}/${comp}}")
                printf "  Compression  : %s%s:1%s (%s algorithm)\n" \
                       "${C_YELLOW}" "${ratio}" "${C_NC}" "${ZRAM_ALGO}"
            fi
        fi
    else
        print_warning "ZRAM swap not yet active - may require reboot"
    fi
    
    # Check if zram module is loaded
    if lsmod | grep -q zram; then
        printf "  ZRAM Module  : %sLoaded%s\n" "${C_GREEN}" "${C_NC}"
    else
        print_warning "ZRAM module is not loaded"
    fi
    
    printf "\n%sManagement Commands:%s\n" "${C_BOLD}" "${C_NC}"
    printf "  View status     : %ssystemctl status %s%s\n" "${C_DIM}" "${SERVICE_NAME:-zramswap}" "${C_NC}"
    printf "  Show swap       : %sswapon --show%s\n" "${C_DIM}" "${C_NC}"
    printf "  Memory stats    : %sfree -h%s\n" "${C_DIM}" "${C_NC}"
    printf "  ZRAM stats      : %szramctl%s\n" "${C_DIM}" "${C_NC}"
    printf "\n"
}

# Main execution function
main() {
    # Clear screen for clean presentation
    clear
    
    print_header
    detect_system
    show_system_info
    show_current_memory
    
    printf "\n%sStarting ZRAM Installation%s\n" "${C_BOLD}" "${C_NC}"
    printf "%s\n" "$(printf '%50s' | tr ' ' '-')"
    
    install_packages
    configure_zram
    run_task "Configuring kernel parameters" configure_kernel_params
    
    # Restart and enable service
    service_action restart
    service_action enable
    
    printf "\n"
    show_final_summary
}

# Signal trap for clean exit
trap 'printf "\n%s[!]%s Operation interrupted by user\n" "${C_RED}" "${C_NC}"; exit 130' INT TERM

# Script entry point
parse_arguments "$@"
check_root
main
