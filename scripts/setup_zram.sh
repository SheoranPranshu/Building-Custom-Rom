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

Options:
  -p PERCENT   ZRAM size percentage (default: ${DEFAULT_ZRAM_PERCENT})
  -a ALGO      Compression algorithm (default: ${DEFAULT_ZRAM_ALGO})
  -r PRIORITY  Swap priority (default: ${DEFAULT_ZRAM_PRIORITY})
  -h           Help
EOF
}

parse_arguments() {
    while getopts "p:a:r:h" opt; do
        case "$opt" in
            p)
                if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 1 ] && [ "$OPTARG" -le 100 ]; then
                    ZRAM_PERCENT="$OPTARG"
                else
                    echo "${C_RED}[✗]${C_NC} Invalid percentage"; exit 1
                fi ;;
            a) ZRAM_ALGO="$OPTARG" ;;
            r)
                if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                    ZRAM_PRIORITY="$OPTARG"
                else
                    echo "${C_RED}[✗]${C_NC} Invalid priority"; exit 1
                fi ;;
            h) usage; exit 0 ;;
            *) usage; exit 1 ;;
        esac
    done
}

check_root() {
    [ "$EUID" -ne 0 ] && echo "${C_RED}[✗] Must run as root${C_NC}" && exit 1
}

print_header() {
    clear 2>/dev/null || true
    echo "${C_CYAN}${C_BOLD}"
    echo "=================================================="
    echo "            ZRAM Configuration Setup"
    echo "=================================================="
    echo "${C_NC}"
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
        PM_UPDATE="apt-get update -y"
        PM_INSTALL="apt-get install -y"
        DISTRO=debian
    else
        echo "${C_RED}[✗] Unsupported distro (this auto-fix requires apt-get)${C_NC}"
        exit 1
    fi
}

fix_missing_zram_module() {
    if modprobe zram >/dev/null 2>&1; then
        return 0
    fi

    echo "${C_YELLOW}[!] Kernel ZRAM module missing — fixing automatically...${C_NC}"

    run_task "Installing linux-modules-extra-$(uname -r)" \
        $PM_INSTALL "linux-modules-extra-$(uname -r)" || \
    run_task "Installing full generic kernel" \
        $PM_INSTALL linux-generic

    echo "${C_YELLOW}Reboot is required to load new kernel modules.${C_NC}"
    echo "${C_GREEN}After reboot, run this script again.${C_NC}"
    exit 0
}

install_zram_pkg() {
    run_task "Updating package repositories" bash -c "$PM_UPDATE"
    run_task "Installing zram-tools" $PM_INSTALL zram-tools
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
vm.swappiness=180
vm.watermark_boost_factor=0
vm.watermark_scale_factor=125
vm.page-cluster=0
EOF
    sysctl -p /etc/sysctl.d/99-zram.conf >/dev/null 2>&1 || true
}

ensure_service() {
    if systemctl list-unit-files --type=service | grep -q "^zramswap.service"; then
        SERVICE=zramswap
        return
    fi

    cat <<EOF >/etc/systemd/system/zramswap.service
[Unit]
Description=ZRAM Swap Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/zramswap start
ExecStop=/usr/sbin/zramswap stop
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    SERVICE=zramswap
}

start_service_or_manual() {
    if systemctl list-unit-files --type=service | grep -q "^${SERVICE}.service"; then
        run_task "Restarting zramswap.service" systemctl restart zramswap.service
        run_task "Enabling zramswap at boot" systemctl enable zramswap.service
    else
        echo "${C_YELLOW}[!] No systemd found — falling back to manual start${C_NC}"
        /usr/sbin/zramswap start || echo "${C_RED}[✗] Manual start failed${C_NC}"
    fi
}

show_final_status() {
    echo
    echo "${C_GREEN}${C_BOLD}[✓] ZRAM configuration complete!${C_NC}"
    echo
    echo "${C_BOLD}Swap Status:${C_NC}"
    swapon --show | sed 's/^/  /' || echo "  (none)"
    echo
    echo "${C_BOLD}ZRAM Devices:${C_NC}"
    zramctl 2>/dev/null | sed 's/^/  /' || echo "  (none)"
    echo
}

main() {
    print_header
    detect_pm
    fix_missing_zram_module
    install_zram_pkg
    run_task "Applying ZRAM configuration" configure_zram
    run_task "Applying kernel tuning" apply_kernel_tuning
    ensure_service
    start_service_or_manual
    show_final_status
}

trap 'echo; echo "${C_YELLOW}[!] Interrupted${C_NC}"; exit 130' INT TERM

parse_arguments "$@"
check_root
main
