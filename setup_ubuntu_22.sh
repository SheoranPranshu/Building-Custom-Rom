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
C_NC='\033[0m'

# Icons
ICON_BUILD="🛠️"
ICON_SETUP="⚙️"
ICON_OK="✓"
ICON_FAIL="✗"
ICON_INFO="ℹ️"
ICON_DL="📥"

# Helper function for running tasks with a spinner
run_task() {
    local msg=$1
    shift
    local cmd=("$@")
    local spinner="/|\\-"
    local i=0
    
    # Run in background and log output
    "${cmd[@]}" &> /tmp/setup_android.log &
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
        cat /tmp/setup_android.log >&2
        echo -e "${C_YELLOW}-----------------${C_NC}" >&2
        exit 1
    fi
}

# --- Main Logic ---
main() {
    # Header
    echo -e "${C_BLUE}--- ${ICON_BUILD} Android Build Environment Setup ---${C_NC}"

    # "Prime the pump" for sudo, so the user is prompted once at the start
    echo -e "${ICON_INFO} This script will need sudo access for package installation."
    sudo -v
    # Keep sudo session alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done &> /dev/null &


    # --- 1. System Preparation ---
    echo -e "\n${C_GREEN}Phase 1: Preparing System Packages${C_NC}"
    run_task "Updating package lists" sudo apt-get update -y
    run_task "Upgrading existing packages" sudo apt-get upgrade -y
    
    local base_packages="unzip tmate git tmux ccache zip"
    run_task "Installing base utilities" sudo apt-get install -y $base_packages


    # --- 2. Android SDK & Repo Tool ---
    echo -e "\n${C_GREEN}Phase 2: Setting up Android Tools${C_NC}"
    cd ~/
    run_task "Downloading platform-tools" wget -q -nc https://dl.google.com/android/repository/platform-tools-latest-linux.zip
    run_task "Unzipping platform-tools" unzip -qo platform-tools-latest-linux.zip -d ~

    # Add to .profile
    printf "${C_BLUE}%s  Checking .profile for PATH entry... ${C_NC}" "$ICON_SETUP"
    local android_path_block='# add Android SDK platform tools to path
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi'
    if ! grep -q 'PATH="$HOME/platform-tools:$PATH"' ~/.profile; then
        echo -e "\n$android_path_block" >> ~/.profile
        printf "\b${C_GREEN}%s${C_NC} (Added)\n" "$ICON_OK"
    else
        printf "\b${C_GREEN}%s${C_NC} (Already exists)\n" "$ICON_OK"
    fi

    # Setup repo tool
    mkdir -p ~/bin
    run_task "Downloading 'repo' tool" curl -s -o ~/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
    chmod a+x ~/bin/repo


    # --- 3. AOSP Build Environment ---
    echo -e "\n${C_GREEN}Phase 3: Running AOSP Environment Script${C_NC}"
    cd ~/
    if [ ! -d "scripts" ]; then
        run_task "Cloning akhilnarang/scripts" git clone -q https://github.com/akhilnarang/scripts
    else
        echo -e "${C_GREEN}${ICON_OK}  akhilnarang/scripts repository already exists.${C_NC}"
    fi
    cd scripts
    
    echo -e "\n${C_YELLOW}--- Handing over to android_build_env.sh (follow its instructions) ---${C_NC}"
    bash setup/android_build_env.sh
    echo -e "${C_YELLOW}------------------- Resuming main script -------------------${C_NC}\n"


    # --- 4. Final Summary ---
    echo -e "${C_GREEN}--- ${ICON_BUILD} Setup Complete! ---${C_NC}"
    echo -e "╭──────────────────────────────────────────────────────────╮"
    echo -e "│                                                          │"
    echo -e "│  ${C_GREEN}${ICON_OK} All packages and tools have been installed.${C_NC}              │"
    echo -e "│                                                          │"
    echo -e "│  ${C_YELLOW}${ICON_INFO} For PATH changes to take effect, you must:${C_NC}           │"
    echo -e "│  ${C_BLUE}1. Open a new terminal window.${C_NC}                        │"
    echo -e "│  ${C_BLUE}2. Or run: source ~/.profile${C_NC}                           │"
    echo -e "│                                                          │"
    echo -e "╰──────────────────────────────────────────────────────────╯"
}

# Run it
main
