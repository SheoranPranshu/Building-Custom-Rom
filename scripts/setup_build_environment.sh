#!/usr/bin/env bash

#
# Universal Android Build Environment Setup
# Compatible with Ubuntu 22x and Debian 12x
# A comprehensive script to prepare your system for AOSP builds
#

set -eo pipefail

# Color definitions
readonly C_BLUE='\033[1;34m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_RED='\033[1;31m'
readonly C_CYAN='\033[1;36m'
readonly C_PURPLE='\033[1;35m'
readonly C_NC='\033[0m'

# Icons
readonly ICON_BUILD="🛠️"
readonly ICON_SETUP="⚙️"
readonly ICON_OK="✓"
readonly ICON_FAIL="✗"
readonly ICON_INFO="ℹ️"
readonly ICON_DOWNLOAD="📥"
readonly ICON_SYSTEM="🖥️"
readonly ICON_PYTHON="🐍"

# Global variables
LOG_FILE="/tmp/android_setup_$(date +%Y%m%d_%H%M%S).log"
SPINNER_PID=""

# System detection
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_CODENAME="$VERSION_CODENAME"
    else
        OS_NAME="Unknown"
        OS_VERSION="Unknown"
        OS_CODENAME="Unknown"
    fi
}

# Display system information
show_system_info() {
    echo -e "${C_PURPLE}╭─────────────────────────────────────────────────────────────╮${C_NC}"
    echo -e "${C_PURPLE}│                    ${ICON_SYSTEM} SYSTEM INFORMATION                     │${C_NC}"
    echo -e "${C_PURPLE}├─────────────────────────────────────────────────────────────┤${C_NC}"
    
    printf "${C_PURPLE}│${C_NC} %-20s ${C_CYAN}%-35s${C_PURPLE} │${C_NC}\n" "Operating System:" "$OS_NAME"
    printf "${C_PURPLE}│${C_NC} %-20s ${C_CYAN}%-35s${C_PURPLE} │${C_NC}\n" "Version:" "$OS_VERSION ($OS_CODENAME)"
    printf "${C_PURPLE}│${C_NC} %-20s ${C_CYAN}%-35s${C_PURPLE} │${C_NC}\n" "Kernel:" "$(uname -r)"
    printf "${C_PURPLE}│${C_NC} %-20s ${C_CYAN}%-35s${C_PURPLE} │${C_NC}\n" "Architecture:" "$(uname -m)"
    printf "${C_PURPLE}│${C_NC} %-20s ${C_CYAN}%-35s${C_PURPLE} │${C_NC}\n" "CPU Cores:" "$(nproc)"
    printf "${C_PURPLE}│${C_NC} %-20s ${C_CYAN}%-35s${C_PURPLE} │${C_NC}\n" "Total Memory:" "$(free -h | awk '/^Mem:/ {print $2}')"
    printf "${C_PURPLE}│${C_NC} %-20s ${C_CYAN}%-35s${C_PURPLE} │${C_NC}\n" "Available Space:" "$(df -h / | awk 'NR==2 {print $4}')"
    
    echo -e "${C_PURPLE}╰─────────────────────────────────────────────────────────────╯${C_NC}"
}

# Enhanced spinner function
show_spinner() {
    local message="$1"
    local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    printf "${C_BLUE}${ICON_SETUP}  %-50s ${C_NC}" "$message"
    
    while true; do
        printf "\b\b${C_YELLOW}%s${C_NC} " "${spinner:i++%${#spinner}:1}"
        sleep 0.1
        if [ $i -eq ${#spinner} ]; then
            i=0
        fi
    done
}

# Task execution with enhanced feedback
run_task() {
    local message="$1"
    shift
    local command=("$@")
    
    # Start spinner in background
    show_spinner "$message" &
    SPINNER_PID=$!
    
    # Execute command with logging
    if "${command[@]}" >> "$LOG_FILE" 2>&1; then
        kill $SPINNER_PID 2>/dev/null || true
        wait $SPINNER_PID 2>/dev/null || true
        printf "\r${C_GREEN}${ICON_OK}  %-50s ${C_GREEN}DONE${C_NC}\n" "$message"
        return 0
    else
        kill $SPINNER_PID 2>/dev/null || true
        wait $SPINNER_PID 2>/dev/null || true
        printf "\r${C_RED}${ICON_FAIL}  %-50s ${C_RED}FAILED${C_NC}\n" "$message"
        echo -e "\n${C_YELLOW}Last 10 lines from log file:${C_NC}"
        tail -n 10 "$LOG_FILE" | sed 's/^/  /'
        return 1
    fi
}

# Initialize sudo session
init_sudo() {
    echo -e "${C_YELLOW}${ICON_INFO} Administrative privileges required for system package installation${C_NC}"
    if ! sudo -v; then
        echo -e "${C_RED}${ICON_FAIL} Failed to obtain sudo privileges${C_NC}"
        exit 1
    fi
    
    # Keep sudo session alive
    (while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done) &>/dev/null &
}

# Update system packages
update_system() {
    echo -e "\n${C_GREEN}═══ Phase 1: System Package Management ═══${C_NC}"
    
    run_task "Updating package database" sudo apt-get update -qq
    run_task "Upgrading existing packages" sudo apt-get upgrade -qq -y
}

# Install essential development packages
install_build_essentials() {
    echo -e "\n${C_GREEN}═══ Phase 2: Development Environment ═══${C_NC}"
    
    local essential_packages=(
        "openssh-server" "screen" "python3" "git" "default-jdk" 
        "android-tools-adb" "bc" "bison" "build-essential" "curl" 
        "flex" "g++-multilib" "gcc-multilib" "gnupg" "gperf" 
        "imagemagick" "lib32ncurses-dev" "lib32readline-dev" 
        "lib32z1-dev" "lz4" "libncurses5-dev" "libsdl1.2-dev" 
        "libssl-dev" "libxml2" "libxml2-utils" "lzop" "pngcrush" 
        "rsync" "schedtool" "squashfs-tools" "xsltproc" "yasm" 
        "zip" "zlib1g-dev" "libtinfo5" "libncurses5" "unzip" 
        "tmate" "tmux" "ccache"
    )
    
    run_task "Installing development packages" sudo apt-get install -qq -y "${essential_packages[@]}"
}

# Install Python 2.7 for legacy compatibility
install_python2() {
    echo -e "\n${C_GREEN}═══ Phase 3: Python 2.7 Legacy Support ═══${C_NC}"
    
    if command -v python2 &> /dev/null; then
        echo -e "${C_GREEN}${ICON_OK}  Python 2.7 already installed: $(python2 --version)${C_NC}"
        return 0
    fi
    
    cd /tmp
    run_task "Downloading Python 2.7.18 source" wget -q https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
    run_task "Extracting Python source archive" tar xzf Python-2.7.18.tgz
    
    cd Python-2.7.18
    run_task "Configuring Python 2.7 build" sudo ./configure --enable-optimizations --quiet
    run_task "Compiling Python 2.7 (this may take time)" sudo make altinstall -j$(nproc) --quiet
    run_task "Creating Python 2 symbolic link" sudo ln -sfn '/usr/local/bin/python2.7' '/usr/bin/python2'
    
    cd "$HOME"
}

# Setup Android development tools
setup_android_tools() {
    echo -e "\n${C_GREEN}═══ Phase 4: Android Development Tools ═══${C_NC}"
    
    # Create bin directory
    mkdir -p "$HOME/bin"
    
    # Download and setup platform-tools
    cd "$HOME"
    if [ ! -d "platform-tools" ]; then
        run_task "Downloading Android platform-tools" wget -q https://dl.google.com/android/repository/platform-tools-latest-linux.zip
        run_task "Extracting platform-tools" unzip -qq platform-tools-latest-linux.zip
        rm -f platform-tools-latest-linux.zip
    else
        echo -e "${C_GREEN}${ICON_OK}  Android platform-tools already installed${C_NC}"
    fi
    
    # Setup repo tool
    if [ ! -f "$HOME/bin/repo" ]; then
        run_task "Downloading repo tool" curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$HOME/bin/repo"
        chmod a+x "$HOME/bin/repo"
    else
        echo -e "${C_GREEN}${ICON_OK}  Repo tool already installed${C_NC}"
    fi
    
    # Update PATH in .profile
    local path_entry='# Android development tools
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi'
    
    if ! grep -q 'platform-tools' "$HOME/.profile" 2>/dev/null; then
        echo -e "\n$path_entry" >> "$HOME/.profile"
        echo -e "${C_GREEN}${ICON_OK}  Updated PATH in .profile${C_NC}"
    else
        echo -e "${C_GREEN}${ICON_OK}  PATH already configured in .profile${C_NC}"
    fi
}

# Setup build environment scripts
setup_build_environment() {
    echo -e "\n${C_GREEN}═══ Phase 5: AOSP Build Environment ═══${C_NC}"
    
    cd "$HOME"
    if [ ! -d "scripts" ]; then
        run_task "Cloning build environment scripts" git clone -q https://github.com/kibria5/scripts.git scripts
    else
        echo -e "${C_GREEN}${ICON_OK}  Build scripts already present${C_NC}"
        cd scripts
        run_task "Updating build scripts" git pull -q origin main || git pull -q origin master
        cd "$HOME"
    fi
    
    cd scripts
    echo -e "\n${C_YELLOW}${ICON_INFO} Executing specialized Android build environment setup...${C_NC}"
    echo -e "${C_CYAN}────────────────────────────────────────────────────────────${C_NC}"
    
    if bash setup/android_build_env.sh; then
        echo -e "${C_CYAN}────────────────────────────────────────────────────────────${C_NC}"
        echo -e "${C_GREEN}${ICON_OK} Build environment configuration completed${C_NC}"
    else
        echo -e "${C_CYAN}────────────────────────────────────────────────────────────${C_NC}"
        echo -e "${C_YELLOW}${ICON_INFO} Build environment setup encountered issues (check output above)${C_NC}"
    fi
    
    cd "$HOME"
}

# Display completion summary
show_completion_summary() {
    echo -e "\n${C_GREEN}╭─────────────────────────────────────────────────────────────╮${C_NC}"
    echo -e "${C_GREEN}│                 ${ICON_BUILD} SETUP COMPLETED SUCCESSFULLY           │${C_NC}"
    echo -e "${C_GREEN}├─────────────────────────────────────────────────────────────┤${C_NC}"
    echo -e "${C_GREEN}│                                                             │${C_NC}"
    echo -e "${C_GREEN}│  ${C_YELLOW}Installed Components:${C_NC}                                    ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│  ${C_CYAN}• Complete development toolchain${C_NC}                        ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│  ${C_CYAN}• Android platform tools and ADB${C_NC}                       ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│  ${C_CYAN}• Python 2.7 for legacy compatibility${C_NC}                  ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│  ${C_CYAN}• Git repo tool for AOSP source management${C_NC}              ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│  ${C_CYAN}• Specialized AOSP build environment${C_NC}                    ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│                                                             │${C_NC}"
    echo -e "${C_GREEN}│  ${C_YELLOW}Next Steps:${C_NC}                                              ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│  ${C_BLUE}1. Open a new terminal session${C_NC}                          ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│  ${C_BLUE}2. Or execute: source ~/.profile${C_NC}                        ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│  ${C_BLUE}3. Verify tools: adb --version && repo --version${C_NC}        ${C_GREEN}│${C_NC}"
    echo -e "${C_GREEN}│                                                             │${C_NC}"
    echo -e "${C_GREEN}│  ${C_PURPLE}Log file: $LOG_FILE${C_NC}"
    printf "${C_GREEN}│%-63s│${C_NC}\n" ""
    echo -e "${C_GREEN}╰─────────────────────────────────────────────────────────────╯${C_NC}"
}

# Cleanup function
cleanup() {
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null || true
        wait $SPINNER_PID 2>/dev/null || true
    fi
}

# Main execution function
main() {
    trap cleanup EXIT
    
    # Header
    echo -e "${C_BLUE}╔═════════════════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_BLUE}║          ${ICON_BUILD} UNIVERSAL ANDROID BUILD ENVIRONMENT SETUP    ║${C_NC}"
    echo -e "${C_BLUE}║                   Compatible with Ubuntu 22x & Debian 12x   ║${C_NC}"
    echo -e "${C_BLUE}╚═════════════════════════════════════════════════════════════╝${C_NC}"
    
    echo -e "\n${C_YELLOW}${ICON_INFO} Initializing system analysis...${C_NC}"
    detect_system
    show_system_info
    
    echo -e "\n${C_YELLOW}${ICON_INFO} All operations will be logged to: ${C_CYAN}$LOG_FILE${C_NC}"
    echo -e "${C_YELLOW}${ICON_INFO} This process may take 2-30 minutes depending on your system${C_NC}"
    
    init_sudo
    update_system
    install_build_essentials
    install_python2
    setup_android_tools
    setup_build_environment
    show_completion_summary
}

# Script entry point
main "$@"
