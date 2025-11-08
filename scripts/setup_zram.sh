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
    C_NC=$(tput sgr0)
    C_GREEN=$(tput setaf 2)
    C_RED=$(tput setaf 1)
    C_YELLOW=$(tput setaf 3)
else
    C_BOLD="" C_NC="" C_GREEN="" C_RED="" C_YELLOW=""
fi

usage() {
    cat <<EOF
Usage: sudo $0 [options]

Options:
  -p PERCENT   ZRAM size percentage (1-100, default: $DEFAULT_ZRAM_PERCENT)
  -a ALGO      Compression algorithm (default: $DEFAULT_ZRAM_ALGO)
  -r PRIORITY  Swap priority (default: $DEFAULT_ZRAM_PRIORITY)
  -h           Show help

Examples:
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
                    echo "[✗] Invalid percentage: $OPTARG" >&2
                    exit 1
                fi
                ;;
            a) ZRAM_ALGO="$OPTARG" ;;
            r)
                if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                    ZRAM_PRIORITY="$OPTARG"
                else
                    echo "[✗] Invalid priority: $OPTARG" >&2
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
        echo "[✗] Must run as root" >&2
        exit 1
    fi
}

run_task() {
    local msg="$1"; shift
    printf "  %-45s " "$msg..."
    if "$@" >/dev/null 2>&1; then
        printf "%s[✓]%s\n" "$C_GREEN" "$C_NC"
        return 0
    else
        printf "%s[✗]%s\n" "$C_RED" "$C_NC"
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
    elif command -v apk >/dev/null 2>&1; then
        PM_UPDATE="apk update"
        PM_INSTALL="apk add"
        DISTRO=alpine
    else
        echo "[✗] Unsupported distro" >&2
        exit 1
    fi
}

check_existing_zram() {
    if lsmod | grep -q "^zram " 2>/dev/null; then
        echo "${C_YELLOW}[!] ZRAM module already loaded${C_NC}"
        if swapon --show | grep -q zram 2>/dev/null; then
            echo "${C_YELLOW}[!] ZRAM swap already active:${C_NC}"
            swapon --show | grep zram
            echo
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
        fi
    fi
}

install_zram_pkg() {
    run_task "Updating repositories" $PM_UPDATE

    case "$DISTRO" in
        debian)
            run_task "Installing zram-tools" $PM_INSTALL zram-tools
            ;;
        fedora|rhel)
            run_task "Installing zram package" $PM_INSTALL zram
            ;;
        arch)
            run_task "Installing zramswap" $PM_INSTALL zramswap || \
            echo "${C_YELLOW}[!] Consider installing from AUR${C_NC}"
            ;;
        opensuse)
            run_task "Installing systemd-zram-service" $PM_INSTALL systemd-zram-service
            ;;
        alpine)
            run_task "Installing zram-tools" $PM_INSTALL zram-tools
            ;;
    esac
}

get_zramswap_path() {
    # Try to find zramswap in PATH first
    if command -v zramswap >/dev/null 2>&1; then
        ZR_BIN="$(command -v zramswap)"
        return 0
    fi

    # Check common locations
    for path in /usr/sbin/zramswap /usr/bin/zramswap /sbin/zramswap; do
        if [ -x "$path" ]; then
            ZR_BIN="$path"
            return 0
        fi
    done
    
    return 1
}

detect_service() {
    # Check if systemctl exists
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
        echo "[✗] Cannot create service: zramswap binary not found" >&2
        return 1
    fi
    
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
    echo "  Created systemd service: zramswap.service"
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

show_info() {
    echo
    echo "System: $(lsb_release -ds 2>/dev/null || uname -s)"
    echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "ZRAM: ${ZRAM_PERCENT}% (algo: $ZRAM_ALGO, priority: $ZRAM_PRIORITY)"
    echo
}

main() {
    clear 2>/dev/null || true
    echo "${C_BOLD}=== ZRAM Configuration Setup ===${C_NC}"
    
    show_info
    check_existing_zram
    detect_pm
    install_zram_pkg

    if ! get_zramswap_path; then
        echo "[✗] zramswap binary not found after install" >&2
        echo "Try manually starting with: sudo modprobe zram" >&2
        exit 1
    fi

    run_task "Configuring ZRAM settings" configure_zram
    run_task "Applying kernel tuning" apply_kernel_tuning

    # Handle systemd service
    if command -v systemctl >/dev/null 2>&1; then
        if ! detect_service; then
            create_service
        fi
        
        if [ -n "$SERVICE" ]; then
            run_task "Restarting $SERVICE" systemctl restart "$SERVICE"
            run_task "Enabling $SERVICE at boot" systemctl enable "$SERVICE"
        fi
    else
        # Non-systemd fallback
        echo "${C_YELLOW}[!] No systemd detected, starting manually${C_NC}"
        $ZR_BIN stop 2>/dev/null || true
        $ZR_BIN start || echo "[!] Manual start failed"
    fi

    echo
    echo "${C_GREEN}${C_BOLD}[✓] ZRAM configuration complete!${C_NC}"
    echo
    echo "Current swap status:"
    swapon --show 2>/dev/null | grep zram || echo "  No ZRAM swap active yet (may need reboot)"
    echo
    echo "ZRAM devices:"
    zramctl 2>/dev/null || lsblk | grep zram 2>/dev/null || echo "  No ZRAM devices visible yet"
}

trap 'echo; echo "${C_YELLOW}[!] Interrupted${C_NC}"; exit 130' INT TERM

parse_arguments "$@"
check_root
main
