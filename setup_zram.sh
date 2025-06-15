#!/usr/bin/env bash

#
# ZRAM Setup Script
# A stylish and simple way to configure zram-tools.
#

# --- Configuration ---
# You can change these values
ZRAM_PERCENT=69
ZRAM_ALGO=zstd
ZRAM_PRIORITY=100

# --- Script Internals ---
# Exit on any error
set -eo pipefail

# Colors
C_BLUE='\033[1;34m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_NC='\033[0m' # No Color

# Icons
ICON_SETUP="⚙️"
ICON_ROCKET="🚀"
ICON_OK="✓"
ICON_FAIL="✗"
ICON_INFO="ℹ️"

# Helper function to run a command with a spinner and nice output
run_task() {
    local msg=$1
    shift
    local cmd=$@
    local spinner="/|\\-"
    local i=0

    # Run command in the background, redirecting output
    $cmd &> /tmp/zram_setup.log &
    local pid=$!

    # Show spinner
    printf "${C_BLUE}%s  %s... ${C_NC}" "$ICON_SETUP" "$msg"
    while kill -0 $pid 2>/dev/null; do
        printf "\b%s" "${spinner:i++%4:1}"
        sleep 0.1
    done

    # Check the command's exit code
    if wait $pid; then
        printf "\b${C_GREEN}%s${C_NC}\n" "$ICON_OK"
    else
        printf "\b${C_RED}%s${C_NC}\n" "$ICON_FAIL"
        echo -e "${C_YELLOW}--- ERROR LOG ---${C_NC}" >&2
        cat /tmp/zram_setup.log >&2
        echo -e "${C_YELLOW}-----------------${C_NC}" >&2
        exit 1
    fi
}

# --- Main Script Logic ---
main() {
    # Check for root/sudo access
    if [[ $EUID -ne 0 ]]; then
        echo -e "${C_RED}${ICON_FAIL} This script must be run with sudo privileges.${C_NC}"
        echo "Please run it as: sudo $0"
        exit 1
    fi

    # Header
    echo -e "${C_BLUE}--- ${ICON_ROCKET} ZRAM Quick Setup ---${C_NC}"
    
    # 1. Install packages
    run_task "Updating package lists" "apt-get update"
    run_task "Installing zram-tools & kernel extras" "apt-get install -y zram-tools linux-modules-extra-$(uname -r)"

    # 2. Configure zram
    local config_msg="Configuring algorithm to ${C_YELLOW}${ZRAM_ALGO}${C_NC} (${C_YELLOW}${ZRAM_PERCENT}%${C_NC} of RAM)"
    local config_cmd="sed -i -r \
        -e 's|^#?ALGO=.*|ALGO=${ZRAM_ALGO}|' \
        -e 's|^#?PERCENT=.*|PERCENT=${ZRAM_PERCENT}|' \
        -e 's|^#?PRIORITY=.*|PRIORITY=${ZRAM_PRIORITY}|' \
        /etc/default/zramswap"
    run_task "$config_msg" "$config_cmd"

    # 3. Restart the service
    run_task "Restarting zram service" "systemctl restart zramswap"
    
    # 4. Final summary
    echo
    echo -e "${C_GREEN}--- ${ICON_OK} ZRAM is Active ---${C_NC}"
    local status=$(swapon --show | grep '/dev/zram')
    local zram_device=$(echo "$status" | awk '{print $1}')
    local zram_size=$(echo "$status" | awk '{print $3}')
    
    echo -e "╭────────────────────────────────────╮"
    echo -e "│                                    │"
    echo -e "│  Device:   ${C_YELLOW}${zram_device}${C_NC}            │"
    echo -e "│  Size:     ${C_GREEN}${zram_size}${C_NC}                 │"
    echo -e "│  Priority: ${C_BLUE}${ZRAM_PRIORITY}${C_NC}               │"
    echo -e "│                                    │"
    echo -e "╰────────────────────────────────────╯"
}

# Run the main function
main
