#!/usr/bin/env bash

#
# Full AOSP Build Host Setup
# Configures a Debian/Ubuntu system with all necessary dependencies and system tweaks.
#

# --- Script Internals ---
set -eo pipefail # Exit on any error

# Colors
C_BLUE='\033[1;34m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_NC='\033[0m'

# Icons
ICON_SETUP="⚙️"
ICON_OK="✓"
ICON_FAIL="✗"
ICON_ROCKET="🚀"

# --- Helper Functions ---
run_task() {
    local msg=$1
    shift
    local cmd=("$@")
    local spinner="/|\\-"
    local i=0
    
    # Run in background and log output
    "${cmd[@]}" &> /tmp/setup_build_host.log &
    local pid=$!

    # Show spinner
    printf "${C_BLUE}%s  %s... ${C_NC}" "$ICON_SETUP" "$msg"
    while kill -0 $pid 2>/dev/null; do
        printf "\b%s" "${spinner:i++%4:1}"
        sleep 0.1
    done

    # Check exit code
    if wait $pid; then
        printf "\b${C_GREEN}%s${C_NC}\n" "$ICON_OK"
    else
        printf "\b${C_RED}%s${C_NC}\n" "$ICON_FAIL"
        echo -e "${C_YELLOW}--- ERROR LOG ---${C_NC}" >&2
        cat /tmp/setup_build_host.log >&2
        echo -e "${C_YELLOW}-----------------${C_NC}" >&2
        exit 1
    fi
}

# --- Main Logic ---
main() {
    # Header
    echo -e "${C_BLUE}--- ${ICON_ROCKET} AOSP Build Host Setup ---${C_NC}"

    # Check for root/sudo access first
    if [[ $EUID -ne 0 ]]; then
        echo -e "\n${C_RED}${ICON_FAIL} This script must be run with sudo privileges.${C_NC}"
        echo "Please run it as: sudo $0"
        exit 1
    fi

    # --- Phase 1: System Update & Dependencies ---
    echo -e "\n${C_GREEN}Phase 1: Installing Dependencies${C_NC}"
    run_task "Updating package lists" apt-get update -y
    run_task "Upgrading existing packages" apt-get upgrade -y
    
    # All packages in one list for a single, efficient install command
    local aosp_packages="bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick \
    lib32readline-dev lib32z1-dev libelf-dev liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync \
    schedtool squashfs-tools xsltproc zip zlib1g-dev gh iotop bashtop nethogs autossh apache2 p7zip neofetch gettext autoconf \
    automake libtool make gcc autopoint patchelf python-is-python3 clang lld llvm gcc-multilib zsh openjdk-17-jdk openjdk-17-jre \
    xmlstarlet micro"

    run_task "Installing all AOSP build dependencies" apt-get install -y $aosp_packages

    # --- Phase 2: Manual & System Configurations ---
    echo -e "\n${C_GREEN}Phase 2: System Configuration${C_NC}"
    
    # Manual install of ncurses5
    local libtinfo_url="http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb"
    local libncurses_url="http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb"
    run_task "Manually installing libtinfo5" "sh -c 'wget -q -O /tmp/libtinfo5.deb $libtinfo_url && dpkg -i /tmp/libtinfo5.deb && rm /tmp/libtinfo5.deb'"
    run_task "Manually installing libncurses5" "sh -c 'wget -q -O /tmp/libncurses5.deb $libncurses_url && dpkg -i /tmp/libncurses5.deb && rm /tmp/libncurses5.deb'"

    # Install repo tool system-wide
    run_task "Installing 'repo' tool system-wide" "sh -c 'curl -s https://storage.googleapis.com/git-repo-downloads/repo -o /usr/bin/repo && chmod a+x /usr/bin/repo'"

    # Disable AppArmor setting
    local apparmor_conf_cmd="echo 'kernel.apparmor_restrict_unprivileged_userns = 0' | tee /etc/sysctl.d/20-apparmor-donotrestrict.conf"
    run_task "Configuring AppArmor rule" "sh -c '$apparmor_conf_cmd'"
    run_task "Applying AppArmor rule immediately" sysctl -w kernel.apparmor_restrict_unprivileged_userns=0


    # --- Final Summary ---
    echo -e "\n${C_GREEN}--- ${ICON_OK} Build Host Setup Complete! ---${C_NC}"
    echo -e "╭──────────────────────────────────────────────────────────╮"
    echo -e "│                                                          │"
    echo -e "│  ${C_GREEN}${ICON_OK} System is now configured for AOSP builds.${C_NC}             │"
    echo -e "│                                                          │"
    echo -e "│  Key changes made:                                       │"
    echo -e "│   - All required build packages installed                │"
    echo -e "│   - 'repo' tool available system-wide                    │"
    echo -e "│   - AppArmor user namespace restriction disabled         │"
    echo -e "│                                                          │"
    echo -e "╰──────────────────────────────────────────────────────────╯"
}

# Run it
main
