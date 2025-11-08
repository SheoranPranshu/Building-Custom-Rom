#!/usr/bin/env bash
# Usage: sudo ./setup_zram.sh [-p percent] [-a algo] [-r priority] [-h]

set -eo pipefail

DEFAULT_ZRAM_PERCENT=69
DEFAULT_ZRAM_ALGO="zstd"
DEFAULT_ZRAM_PRIORITY=100

ZRAM_PERCENT="$DEFAULT_ZRAM_PERCENT"
ZRAM_ALGO="$DEFAULT_ZRAM_ALGO"
ZRAM_PRIORITY="$DEFAULT_ZRAM_PRIORITY"

# Colors
if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    C_BOLD=$(tput bold)
    C_DIM=$(tput dim)
    C_NC=$(tput sgr0)
    C_RED=$(tput setaf 1)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_BLUE=$(tput setaf 4)
    C_CYAN=$(tput setaf 6)
else
    C_BOLD="" C_DIM="" C_NC=""
    C_RED="" C_GREEN="" C_YELLOW=""
    C_BLUE="" C_CYAN=""
fi

usage() {
    cat <<EOF
${C_BOLD}Usage:${C_NC} sudo $0 [options]

${C_BOLD}Options:${C_NC}
  ${C_YELLOW}-p${C_NC} PERCENT   ZRAM size percentage (default: ${DEFAULT_ZRAM_PERCENT})
  ${C_YELLOW}-a${C_NC} ALGO      Compression algorithm (default: ${DEFAULT_ZRAM_ALGO})
  ${C_YELLOW}-r${C_NC} PRIORITY  Swap priority (default: ${DEFAULT_ZRAM_PRIORITY})
  ${C_YELLOW}-h${C_NC}           Help

${C_BOLD}Examples:${C_NC}
  sudo $0              # Use defaults
  sudo $0 -p 50        # 50% of RAM
  sudo $0 -p 50 -a lz4 # 50% with lz4
EOF
}

parse_arguments() {
    while getopts "p:a:r:h" opt; do
        case "$opt" in
            p)
                if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 1 ] && [ "$OPTARG" -le 100 ]; then
                    ZRAM_PERCENT="$OPTARG"
                else
                    echo "${C_RED}[✗]${C_NC} Invalid percentage" >&2
                    exit 1
                fi
                ;;
            a) ZRAM_ALGO="$OPTARG" ;;
            r)
                if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                    ZRAM_PRIORITY="$OPTARG"
                else
                    echo "${C_RED}[✗]${C_NC} Invalid priority" >&2
                    exit 1
                fi
                ;;
            h) usage; exit 0 ;;
            *) usage; exit 1 ;;
        esac
    done
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "${C_RED}[✗]${C_NC} Must run as root" >&2
        exit 1
    fi
}

print_header() {
    clear 2>/dev/null || true
    echo "${C_CYAN}${C_BOLD}"
    echo "=================================================="
    echo "            ZRAM Configuration Setup"
    echo "=================================================="
    echo "${C_NC}"
}

print_info() {
    echo "${C_BOLD}System Information:${C_NC}"
    echo "  Distribution : $(lsb_release -ds 2>/dev/null || uname -s)"
    echo "  Kernel       : $(uname -r)"
    echo "  Total RAM    : $(free -h | awk '/^Mem:/ {print $2}')"
    echo
    echo "${C_BOLD}Configuration:${C_NC}"
    echo "  ZRAM Size    : ${ZRAM_PERCENT}%"
    echo "  Algorithm    : ${ZRAM_ALGO}"
    echo "  Priority     : ${ZRAM_PRIORITY}"
    echo
}

run_task() {
    local msg="$1"; shift
    printf "  %-46s " "$msg..."
    if "$@" >/dev/null 2>&1; then
        printf "${C_GREEN}[✓]${C_NC}\n"
        return 0
    else
        printf "${C_RED}[✗]${C_NC}\n"
        return 1
    fi
}

detect_pm() {
    if command -v apt-get >/dev/null 2>&1; then
        PM_UPDATE="apt-get update"
        PM_INSTALL="apt-get install -y"
        DISTRO=debian
    elif command -v dnf >/dev/null 2>&1; then
        PM_UPDATE="dnf check-update || true"
        PM_INSTALL="dnf install -y"
        DISTRO=fedora
    elif command -v yum >/dev/null 2>&1; then
        PM_UPDATE="yum check-update || true"
        PM_INSTALL="yum install -y"
        DISTRO=rhel
    elif command -v pacman >/dev/null 2>&1; then
        PM_UPDATE="pacman -Sy"
        PM_INSTALL="pacman -S --noconfirm"
        DISTRO=arch
    elif command -v zypper >/dev/null 2>&1; then
        PM_UPDATE="zypper refresh"
        PM_INSTALL="zypper install -y"
        DISTRO=opensuse
    else
        echo "${C_RED}[✗]${C_NC} Unsupported distro" >&2
        exit 1
    fi
}

install_zram_pkg() {
    run_task "Updating package repositories" $PM_UPDATE

    case "$DISTRO" in
        debian)
            run_task "Installing zram-tools" $PM_INSTALL zram-tools
            ;;
        fedora|rhel)
            run_task "Installing zram package" $PM_INSTALL zram
            ;;
        arch)
            run_task "Installing zramswap" $PM_INSTALL zramswap || true
            ;;
        opensuse)
            run_task "Installing systemd-zram-service" $PM_INSTALL systemd-zram-service
            ;;
    esac
}

get_zramswap_path() {
    # Check common locations for Ubuntu/Debian
    for path in /usr/sbin/zramswap /usr/bin/zramswap /sbin/zramswap; do
        if [ -x "$path" ]; then
            ZR_BIN="$path"
            return 0
        fi
    done
    
    # Try command -v as fallback
    if command -v zramswap >/dev/null 2>&1; then
        ZR_BIN="$(command -v zramswap)"
        return 0
    fi
    
    return 1
}

detect_service() {
    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi
    
    for name in zramswap zram-swap zramd zram systemd-zram-setup@zram0; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${name}.service"; then
            SERVICE="$name"
            return 0
        fi
    done
    return 1
}

create_service() {
    if [ -z "$ZR_BIN" ]; then
        return 1
    fi
    
    echo "  Creating systemd service file..."
    
    cat <<EOF >/etc/systemd/system/zramswap.service
[Unit]
Description=ZRAM Swap Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$ZR_BIN start
ExecStop=$ZR_BIN stop
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1
    SERVICE="zramswap"
    printf "  %-46s ${C_GREEN}[✓]${C_NC}\n" "Created zramswap.service"
}

configure_zram() {
    CONF="/etc/default/zramswap"
    [ -f "$CONF" ] && cp "$CONF" "${CONF}.bak-$(date +%s)"

    cat <<EOF > "$CONF"
# ZRAM Configuration
ALGO=$ZRAM_ALGO
PERCENT=$ZRAM_PERCENT
PRIORITY=$ZRAM_PRIORITY
EOF
}

apply_kernel_tuning() {
    cat <<EOF >/etc/sysctl.d/99-zram.conf
# ZRAM optimizations
vm.swappiness=180
vm.watermark_boost_factor=0
vm.watermark_scale_factor=125
vm.page-cluster=0
EOF

    sysctl -p /etc/sysctl.d/99-zram.conf >/dev/null 2>&1 || true
}

show_final_status() {
    echo
    echo "${C_GREEN}${C_BOLD}[✓] ZRAM configuration complete!${C_NC}"
    echo
    echo "${C_BOLD}Current Swap Status:${C_NC}"
    if swapon --show 2>/dev/null | grep -q zram; then
        swapon --show | grep zram | sed 's/^/  /'
    else
        echo "  ${C_YELLOW}No ZRAM swap active yet (may need reboot)${C_NC}"
    fi
    
    echo
    echo "${C_BOLD}ZRAM Devices:${C_NC}"
    if command -v zramctl >/dev/null 2>&1; then
        zramctl 2>/dev/null | sed 's/^/  /' || echo "  ${C_YELLOW}No devices visible yet${C_NC}"
    fi
    
    echo
    echo "${C_BOLD}Management Commands:${C_NC}"
    echo "  View status  : ${C_DIM}systemctl status ${SERVICE:-zramswap}${C_NC}"
    echo "  Show swap    : ${C_DIM}swapon --show${C_NC}"
    echo "  Memory stats : ${C_DIM}free -h${C_NC}"
    echo "  ZRAM stats   : ${C_DIM}zramctl${C_NC}"
    echo
}

main() {
    print_header
    print_info
    
    echo "${C_BOLD}Starting Installation${C_NC}"
    echo "--------------------------------------------------"
    
    detect_pm
    install_zram_pkg

    if ! get_zramswap_path; then
        echo "${C_RED}[✗]${C_NC} zramswap binary not found" >&2
        exit 1
    fi

    run_task "Writing ZRAM configuration" configure_zram
    run_task "Applying kernel parameters" apply_kernel_tuning

    # Handle missing service file
    if ! detect_service && [ "$DISTRO" = "debian" ]; then
        create_service
    fi
    
    if [ -n "$SERVICE" ]; then
        run_task "Restarting $SERVICE service" systemctl restart "$SERVICE"
        run_task "Enabling $SERVICE at boot" systemctl enable "$SERVICE"
    else
        # Manual fallback
        echo "  ${C_YELLOW}Starting ZRAM manually...${C_NC}"
        $ZR_BIN stop 2>/dev/null || true
        run_task "Starting ZRAM swap" $ZR_BIN start
    fi

    show_final_status
}

trap 'echo; echo "${C_YELLOW}[!] Interrupted${C_NC}"; exit 130' INT TERM

parse_arguments "$@"
check_root
main
