#!/usr/bin/env bash

#
# Android Build Environment Setup
# A streamlined and stylish script to prepare a Debian/Ubuntu system for AOSP builds.
#

# --- Script Internals ---
set -eo pipefail # Exit on any error

# Colors
C_BLUE='\033[1;34m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_CYAN='\033[1;36m'
C_MAGENTA='\033[1;35m'
C_GRAY='\033[1;90m'
C_NC='\033[0m'
C_BOLD='\033[1m'

# Icons
ICON_BUILD="🛠️"
ICON_SETUP="⚙️"
ICON_OK="✓"
ICON_FAIL="✗"
ICON_INFO="ℹ️"
ICON_DL="📥"
ICON_ROCKET="🚀"
ICON_PACKAGE="📦"
ICON_ANDROID="🤖"
ICON_SYSTEM="💻"

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=7

# Helper function for step display
show_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local msg=$1
    echo -e "\n${C_CYAN}[${CURRENT_STEP}/${TOTAL_STEPS}]${C_NC} ${C_BOLD}${msg}${C_NC}"
    echo -e "${C_GRAY}────────────────────────────────────────${C_NC}"
}

# Helper function for running tasks with a spinner
run_task() {
    local msg=$1
    shift
    local cmd=("$@")
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    # Run in background and log output
    "${cmd[@]}" &> /tmp/setup_android.log &
    local pid=$!

    # Show spinner with message
    printf "  ${C_GRAY}→${C_NC} %s" "$msg"
    while kill -0 $pid 2>/dev/null; do
        printf " ${C_BLUE}%s${C_NC}" "${spinner:i++%10:1}"
        sleep 0.1
        printf "\b\b"
    done

    # Check exit code
    if wait $pid; then
        printf "\b\b ${C_GREEN}${ICON_OK} Done${C_NC}\n"
        return 0
    else
        printf "\b\b ${C_RED}${ICON_FAIL} Failed${C_NC}\n"
        echo -e "${C_YELLOW}--- ERROR LOG ---${C_NC}" >&2
        tail -n 20 /tmp/setup_android.log >&2
        echo -e "${C_YELLOW}-----------------${C_NC}" >&2
        exit 1
    fi
}

# Silent task runner (no output shown)
run_silent() {
    "$@" &> /tmp/setup_android.log
}

# Get system information
get_system_info() {
    # OS Info
    local os_name=$(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
    
    # Kernel
    local kernel=$(uname -r)
    
    # RAM
    local ram_total=$(free -h | awk '/^Mem:/ {print $2}')
    local ram_used=$(free -h | awk '/^Mem:/ {print $3}')
    
    # Storage
    local storage_total=$(df -h / | awk 'NR==2 {print $2}')
    local storage_used=$(df -h / | awk 'NR==2 {print $3}')
    local storage_avail=$(df -h / | awk 'NR==2 {print $4}')
    
    # CPU
    local cpu_model=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
    local cpu_cores=$(nproc)
    
    echo -e "\n${C_CYAN}${ICON_SYSTEM} System Information${C_NC}"
    echo -e "╭──────────────────────────────────────────────────────────────────╮"
    printf "│ %-64s │\n" "${C_BOLD}Operating System:${C_NC} $os_name"
    printf "│ %-64s │\n" "${C_BOLD}Kernel:${C_NC} $kernel"
    printf "│ %-64s │\n" "${C_BOLD}CPU:${C_NC} $cpu_model ($cpu_cores cores)"
    printf "│ %-64s │\n" "${C_BOLD}RAM:${C_NC} $ram_used / $ram_total"
    printf "│ %-64s │\n" "${C_BOLD}Storage (/):${C_NC} Used: $storage_used | Available: $storage_avail | Total: $storage_total"
    echo -e "╰──────────────────────────────────────────────────────────────────╯"
}

# Setup byobu alias function
setup_byobu_function() {
    local byobu_function='
# Byobu session manager
b() {
    if [ $# -eq 0 ]; then
        byobu
    else
        session_name="$1"
        byobu has-session -t "$session_name" 2>/dev/null
        if [ $? -eq 0 ]; then
            byobu attach-session -t "$session_name"
        else
            byobu new-session -s "$session_name"
        fi
    fi
}'
    
    # Add to .bashrc if not already present
    if ! grep -q "# Byobu session manager" ~/.bashrc 2>/dev/null; then
        echo "$byobu_function" >> ~/.bashrc
    fi
}

# --- Main Logic ---
main() {
    clear
    
    # Header
    echo -e "${C_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
    echo -e "${C_BOLD}                   ${ICON_ANDROID} Android Build Environment Setup ${ICON_BUILD}${C_NC}"
    echo -e "${C_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
    echo -e "${C_GRAY}Preparing your system for Android Open Source Project (AOSP) development${C_NC}"
    echo

    # Request sudo access upfront
    echo -e "${ICON_INFO} ${C_YELLOW}This script requires administrator privileges${C_NC}"
    sudo -v
    # Keep sudo session alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done &> /dev/null &

    # Step 1: Update System
    show_step "${ICON_PACKAGE} Updating System Packages"
    run_task "Refreshing package lists" sudo apt-get update -y
    run_task "Upgrading existing packages" sudo apt-get upgrade -y

    # Step 2: Install Base Utilities
    show_step "${ICON_SETUP} Installing Essential Tools"
    local base_packages="unzip git ccache zip curl wget byobu"
    run_task "Installing build utilities" sudo apt-get install -y $base_packages

    # Step 3: Android Platform Tools
    show_step "${ICON_DL} Downloading Android Platform Tools"
    cd ~/
    if [ ! -f "platform-tools-latest-linux.zip" ]; then
        run_task "Fetching platform-tools" wget -q https://dl.google.com/android/repository/platform-tools-latest-linux.zip
    else
        echo -e "  ${C_GRAY}→${C_NC} Platform tools already downloaded ${C_GREEN}${ICON_OK} Skipped${C_NC}"
    fi
    run_task "Extracting platform-tools" unzip -qo platform-tools-latest-linux.zip -d ~

    # Step 4: Configure PATH
    show_step "${ICON_SETUP} Configuring Environment Variables"
    printf "  ${C_GRAY}→${C_NC} Setting up PATH in .profile"
    local android_path_block='# add Android SDK platform tools to path
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi'
    if ! grep -q 'PATH="$HOME/platform-tools:$PATH"' ~/.profile; then
        echo -e "\n$android_path_block" >> ~/.profile
        printf " ${C_GREEN}${ICON_OK} Added${C_NC}\n"
    else
        printf " ${C_GREEN}${ICON_OK} Already configured${C_NC}\n"
    fi

    # Step 5: Install Repo Tool
    show_step "${ICON_DL} Setting up Google Repo Tool"
    mkdir -p ~/bin
    run_task "Downloading repo tool" curl -s -o ~/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
    chmod a+x ~/bin/repo
    echo -e "  ${C_GRAY}→${C_NC} Repo tool installed to ~/bin/repo ${C_GREEN}${ICON_OK} Done${C_NC}"

    # Step 6: AOSP Build Dependencies
    show_step "${ICON_BUILD} Installing AOSP Build Dependencies"
    cd ~/
    if [ ! -d "scripts" ]; then
        run_task "Cloning build environment scripts" git clone -q https://github.com/akhilnarang/scripts
    else
        echo -e "  ${C_GRAY}→${C_NC} Build scripts already present ${C_GREEN}${ICON_OK} Skipped${C_NC}"
    fi
    
    cd scripts
    echo -e "  ${C_GRAY}→${C_NC} Running AOSP environment setup (this may take a while)..."
    if bash setup/android_build_env.sh &> /tmp/aosp_env_setup.log; then
        echo -e "  ${C_GRAY}→${C_NC} AOSP dependencies installed ${C_GREEN}${ICON_OK} Done${C_NC}"
    else
        echo -e "  ${C_GRAY}→${C_NC} AOSP dependencies installation ${C_RED}${ICON_FAIL} Failed${C_NC}"
        echo -e "${C_YELLOW}Check /tmp/aosp_env_setup.log for details${C_NC}"
    fi

    # Step 7: Configure Byobu
    show_step "${ICON_SETUP} Configuring Byobu Session Manager"
    setup_byobu_function
    echo -e "  ${C_GRAY}→${C_NC} Byobu helper function configured ${C_GREEN}${ICON_OK} Done${C_NC}"

    # Display system information
    get_system_info

    # Final Summary
    echo -e "\n${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
    echo -e "${C_BOLD}               ${ICON_ROCKET} Setup Complete! Your system is ready ${ICON_OK}${C_NC}"
    echo -e "${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
    
    echo -e "\n${C_CYAN}${ICON_INFO} Quick Start Guide:${C_NC}"
    echo -e "╭──────────────────────────────────────────────────────────────────────╮"
    echo -e "│                                                                      │"
    echo -e "│  ${C_BOLD}1. Reload your environment:${C_NC}                                        │"
    echo -e "│     ${C_BLUE}source ~/.profile && source ~/.bashrc${C_NC}                          │"
    echo -e "│                                                                      │"
    echo -e "│  ${C_BOLD}2. Use Byobu for persistent sessions:${C_NC}                              │"
    echo -e "│     ${C_BLUE}b${C_NC} ${C_GRAY}<session-name>${C_NC}  - Create or attach to a session             │"
    echo -e "│     ${C_BLUE}b${C_NC}                - List/manage sessions                         │"
    echo -e "│                                                                      │"
    echo -e "│  ${C_BOLD}Example:${C_NC}                                                            │"
    echo -e "│     ${C_BLUE}b android${C_NC}        - Create/attach to 'android' session          │"
    echo -e "│     ${C_BLUE}b lineage${C_NC}        - Create/attach to 'lineage' session          │"
    echo -e "│                                                                      │"
    echo -e "│  ${C_BOLD}3. Verify installation:${C_NC}                                            │"
    echo -e "│     ${C_BLUE}adb --version${C_NC}    - Check Android Debug Bridge                  │"
    echo -e "│     ${C_BLUE}repo --version${C_NC}   - Check repo tool                             │"
    echo -e "│                                                                      │"
    echo -e "╰──────────────────────────────────────────────────────────────────────╯"
    
    echo -e "\n${C_GRAY}Log files saved to /tmp/ for troubleshooting${C_NC}"
    echo -e "${C_MAGENTA}Happy Building! ${ICON_ANDROID}${C_NC}\n"
}

# Run it
main
