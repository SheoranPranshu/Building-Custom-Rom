#!/usr/bin/env bash

# ⚠️ This script is intended for Ubuntu 22.04 LTS. It may not function as expected on other systems.

set -euo pipefail
IFS=$'\n\t'

# Terminal Colors
readonly C_BLUE='\033[1;34m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_RED='\033[1;31m'
readonly C_CYAN='\033[1;36m'
readonly C_MAGENTA='\033[1;35m'
readonly C_GRAY='\033[1;90m'
readonly C_WHITE='\033[1;37m'
readonly C_NC='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'

# Icons
readonly ICON_BUILD="🛠️"
readonly ICON_SETUP="⚙️"
readonly ICON_OK="✓"
readonly ICON_FAIL="✗"
readonly ICON_INFO="◆"
readonly ICON_DL="↓"
readonly ICON_ROCKET="→"
readonly ICON_PACKAGE="◈"
readonly ICON_ANDROID="◉"
readonly ICON_SYSTEM="◎"
readonly ICON_WARN="!"
readonly ICON_PROGRESS="◌"
readonly ICON_ARROW="▸"

# Script Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/android-setup"
readonly LOG_FILE="${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
readonly PLATFORM_TOOLS_DIR="/opt/android-platform-tools"
readonly BUILD_SCRIPTS_DIR="/opt/android-build-scripts"

CURRENT_STEP=0
TOTAL_STEPS=9

# Setup logging directory and redirect output to log file
setup_logging() {
    mkdir -p "$LOG_DIR"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
}

# Display the main header with Android branding
print_header() {
    clear
    echo
    echo -e "${C_CYAN}╔══════════════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_CYAN}║${C_NC}                                                          ${C_CYAN}║${C_NC}"
    echo -e "${C_CYAN}║${C_NC}     ${C_WHITE}${ICON_ANDROID}  ${C_BOLD}ANDROID BUILD ENVIRONMENT SETUP${C_NC}  ${ICON_BUILD}         ${C_CYAN}║${C_NC}"
    echo -e "${C_CYAN}║${C_NC}                                                          ${C_CYAN}║${C_NC}"
    echo -e "${C_CYAN}║${C_NC}        ${C_DIM}Automated setup for AOSP development${C_NC}            ${C_CYAN}║${C_NC}"
    echo -e "${C_CYAN}║${C_NC}           ${C_DIM}Ubuntu 22.04 LTS Optimized${C_NC}                   ${C_CYAN}║${C_NC}"
    echo -e "${C_CYAN}║${C_NC}                                                          ${C_CYAN}║${C_NC}"
    echo -e "${C_CYAN}╚══════════════════════════════════════════════════════════╝${C_NC}"
    echo
}

# Verify Ubuntu version compatibility
check_ubuntu_version() {
    if ! command -v lsb_release &>/dev/null; then
        apt-get update -qq && apt-get install -qq -y lsb-release
    fi
    
    local version=$(lsb_release -rs 2>/dev/null || echo "0")
    local os_name=$(lsb_release -ds 2>/dev/null || echo "Unknown")
    
    echo -e "${C_WHITE}┌─ ${ICON_SYSTEM} System Check${C_NC}"
    echo -e "${C_WHITE}│${C_NC}"
    
    if [[ "$version" != "22.04" ]]; then
        echo -e "${C_WHITE}│${C_NC}  ${C_YELLOW}${ICON_WARN} Warning: Optimized for Ubuntu 22.04 LTS${C_NC}"
        echo -e "${C_WHITE}│${C_NC}  ${C_YELLOW}Current: ${os_name}${C_NC}"
        echo -e "${C_WHITE}│${C_NC}"
        echo -e -n "${C_WHITE}└${C_NC}  Continue anyway? (y/N): "
        read -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    else
        echo -e "${C_WHITE}│${C_NC}  ${C_GREEN}${ICON_OK}${C_NC} ${os_name}"
        echo -e "${C_WHITE}└${C_NC}  ${C_GREEN}Compatible system detected${C_NC}"
    fi
    echo
}

# Display current step progress
show_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local msg=$1
    echo
    echo -e "${C_BLUE}╭──────────────────────────────────────────────────────────╮${C_NC}"
    echo -e "${C_BLUE}│${C_NC} ${C_BOLD}${C_WHITE}[${CURRENT_STEP}/${TOTAL_STEPS}] ${msg}${C_NC}"
    echo -e "${C_BLUE}╰──────────────────────────────────────────────────────────╯${C_NC}"
}

# Execute a task with spinner
run_task() {
    local msg=$1
    shift
    local cmd=("$@")
    local temp_log=$(mktemp)
    local spinner=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    
    printf "  ${C_WHITE}${ICON_ARROW}${C_NC} %-45s" "$msg"
    
    "${cmd[@]}" &> "$temp_log" &
    local pid=$!
    
    while kill -0 $pid 2>/dev/null; do
        printf "${C_CYAN}%s${C_NC}" "${spinner[$((i++ % 10))]}"
        sleep 0.1
        printf "\b"
    done
    
    if wait $pid; then
        printf "\b[${C_GREEN}${ICON_OK}${C_NC}]\n"
        rm -f "$temp_log"
    else
        printf "\b[${C_RED}${ICON_FAIL}${C_NC}]\n"
        echo
        echo -e "${C_RED}┌─ Error Output ────────────────────────┐${C_NC}" >&2
        tail -n 10 "$temp_log" | sed 's/^/│ /' >&2
        echo -e "${C_RED}└───────────────────────────────────────┘${C_NC}" >&2
        rm -f "$temp_log"
        exit 1
    fi
}

# Collect and display system information
get_system_info() {
    local os_name=$(lsb_release -ds 2>/dev/null || echo "Unknown")
    local kernel=$(uname -r)
    local ram_total=$(free -h | awk '/^Mem:/ {print $2}')
    local ram_avail=$(free -h | awk '/^Mem:/ {print $7}')
    local storage_info=$(df -h / | awk 'NR==2 {printf "%s/%s", $3, $2}')
    local storage_avail=$(df -h / | awk 'NR==2 {print $4}')
    local cpu_model=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs | head -c 35)
    local cpu_cores=$(nproc)
    
    echo
    echo -e "${C_MAGENTA}╭─ ${ICON_SYSTEM} System Information ────────────────────────╮${C_NC}"
    echo -e "${C_MAGENTA}│${C_NC}  ${C_WHITE}OS:${C_NC}       ${os_name}"
    echo -e "${C_MAGENTA}│${C_NC}  ${C_WHITE}Kernel:${C_NC}   ${kernel}"
    echo -e "${C_MAGENTA}│${C_NC}  ${C_WHITE}CPU:${C_NC}      ${cpu_model}... (${cpu_cores} cores)"
    echo -e "${C_MAGENTA}│${C_NC}  ${C_WHITE}RAM:${C_NC}      ${ram_avail} available of ${ram_total}"
    echo -e "${C_MAGENTA}│${C_NC}  ${C_WHITE}Storage:${C_NC}  ${storage_info} (${storage_avail} free)"
    echo -e "${C_MAGENTA}╰───────────────────────────────────────────────────╯${C_NC}"
}

# Configure environment and byobu
setup_environment_and_byobu() {
    cat > /etc/profile.d/android-env.sh << 'EOF'
# Android development environment
export PATH="/opt/android-platform-tools/platform-tools:$PATH"
export PATH="/usr/local/bin:$PATH"
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G
export ANDROID_HOME="/opt/android-platform-tools"

b() {
    if [ $# -eq 0 ]; then
        if byobu list-sessions 2>/dev/null; then
            echo "Use 'b <session-name>' to attach/create a session"
        else
            echo "No active sessions. Use 'b <session-name>' to create one"
        fi
    else
        local session_name="$1"
        if byobu has-session -t "$session_name" 2>/dev/null; then
            byobu attach-session -t "$session_name"
        else
            byobu new-session -s "$session_name"
        fi
    fi
}
EOF
    chmod 644 /etc/profile.d/android-env.sh
}

# Repo Safety Lock Setup
setup_repo_safety_lock() {
    echo
    echo -e "${C_WHITE}┌─ ${ICON_WARN} Repo Safety Lock${C_NC}"
    echo -e "${C_WHITE}│${C_NC}  ${C_DIM}Prevents accidental repo init in home directory.${C_NC}"
    echo -e "${C_WHITE}│${C_NC}  ${C_DIM}Recommended for avoiding accidental giant syncs.${C_NC}"
    echo -e -n "${C_WHITE}└${C_NC}  Enable the safety lock? (y/N): "
    read -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${C_GREEN}${ICON_OK} Smart choice!${C_NC} Securing your workspace from repo chaos."
        echo -e "${C_WHITE}${ICON_PROGRESS} Installing safety lock...${C_NC}"

        local safety_script="/etc/default/repo-safety.sh"
        if sudo curl -fsSL -o "$safety_script" \
            "https://github.com/SheoranPranshu/Building-Help/raw/refs/heads/main/repo-safety.sh"; then
            sudo chmod +x "$safety_script"
            if [[ -x "$safety_script" ]]; then
                echo -e "${C_GREEN}${ICON_OK} Safety lock installed:${C_NC} ${C_DIM}$safety_script${C_NC}"
                echo -e "${C_CYAN}Tip:${C_NC} Remove with 'sudo rm -f $safety_script' if needed."
            else
                echo -e "${C_YELLOW}${ICON_WARN} Script downloaded but not executable.${C_NC}"
            fi
        else
            echo -e "${C_RED}${ICON_FAIL} Failed to install safety lock.${C_NC}"
        fi
    else
        echo -e "${C_YELLOW}${ICON_INFO} Skipping repo safety lock. Be cautious, builder.${C_NC}"
    fi
    echo
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${C_RED}╭──────────────────────────────────────────────────╮${C_NC}"
        echo -e "${C_RED}│${C_NC}  ${C_RED}${ICON_FAIL} Root privileges required${C_NC}                   ${C_RED}│${C_NC}"
        echo -e "${C_RED}│${C_NC}  ${C_YELLOW}Usage: sudo $0${C_NC}                           ${C_RED}│${C_NC}"
        echo -e "${C_RED}╰──────────────────────────────────────────────────╯${C_NC}"
        exit 1
    fi
}

# Network check
verify_network() {
    echo -e "${C_WHITE}${ICON_INFO} Checking network connectivity...${C_NC}"
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo -e "${C_RED}${ICON_FAIL} No internet connection detected.${C_NC}"
        exit 1
    fi
    echo -e "${C_GREEN}${ICON_OK} Network connection verified.${C_NC}"
    echo
}

# Cleanup
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo
        echo -e "${C_RED}╭──────────────────────────────────────────────────╮${C_NC}"
        echo -e "${C_RED}│${C_NC}  ${C_RED}${ICON_FAIL} Setup failed!${C_NC}                             ${C_RED}│${C_NC}"
        echo -e "${C_RED}│${C_NC}  ${C_DIM}Log file: $LOG_FILE${C_NC}"
        echo -e "${C_RED}╰──────────────────────────────────────────────────╯${C_NC}"
    fi
}

trap cleanup_on_exit EXIT

# Main Execution Flow
main() {
    setup_logging
    print_header
    check_root
    check_ubuntu_version
    verify_network

    # Step 1
    show_step "${ICON_PACKAGE} Initial System Update"
    export DEBIAN_FRONTEND=noninteractive
    run_task "Updating package lists" apt-get update -qq
    run_task "Upgrading system packages" apt-get upgrade -qq -y
    run_task "Fixing dependencies" apt-get install -qq -f -y

    # Step 2
    show_step "${ICON_SETUP} Installing Development Tools"
    local essential_packages=(build-essential curl wget git nano tmux byobu unzip zip ccache software-properties-common lsb-release gnupg2 ca-certificates python3 python3-pip cmake ninja-build pkg-config)
    run_task "Installing essential packages" apt-get install -qq -y "${essential_packages[@]}"

    # Step 3
    show_step "${ICON_DL} Installing GitHub CLI"
    if ! command -v gh &>/dev/null; then
        run_task "Adding GitHub CLI repository" bash -c "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        run_task "Updating package lists" apt-get update -qq
        run_task "Installing GitHub CLI" apt-get install -qq -y gh
    else
        echo -e "  ${C_WHITE}${ICON_ARROW}${C_NC} GitHub CLI already installed [${C_GREEN}${ICON_OK}${C_NC}]"
    fi

    # Step 4
    show_step "${ICON_ANDROID} Installing Android Platform Tools"
    mkdir -p "$PLATFORM_TOOLS_DIR"
    local platform_tools_url="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
    local platform_tools_zip="/tmp/platform-tools.zip"
    
    if [[ ! -d "$PLATFORM_TOOLS_DIR/platform-tools" ]]; then
        run_task "Downloading platform-tools" wget -q -O "$platform_tools_zip" "$platform_tools_url"
        run_task "Extracting platform-tools" unzip -qo "$platform_tools_zip" -d "$PLATFORM_TOOLS_DIR"
        rm -f "$platform_tools_zip"
    else
        echo -e "  ${C_WHITE}${ICON_ARROW}${C_NC} Platform tools already installed [${C_GREEN}${ICON_OK}${C_NC}]"
    fi
    
    printf "  ${C_WHITE}${ICON_ARROW}${C_NC} %-45s" "Creating system symlinks"
    for tool in adb fastboot; do
        ln -sf "$PLATFORM_TOOLS_DIR/platform-tools/$tool" "/usr/local/bin/$tool" 2>/dev/null || true
    done
    printf "[${C_GREEN}${ICON_OK}${C_NC}]\n"

    # Step 5
    show_step "${ICON_SETUP} Configuring Environment"
    setup_environment_and_byobu
    echo -e "  ${C_WHITE}${ICON_ARROW}${C_NC} Environment configured [${C_GREEN}${ICON_OK}${C_NC}]"

    # Step 6
    show_step "${ICON_DL} Installing Repo Tool"
    local repo_url="https://storage.googleapis.com/git-repo-downloads/repo"
    run_task "Downloading repo tool" curl -fsSL -o /usr/local/bin/repo "$repo_url"
    chmod a+rx /usr/local/bin/repo
    echo -e "  ${C_WHITE}${ICON_ARROW}${C_NC} Repo tool installed [${C_GREEN}${ICON_OK}${C_NC}]"

    # Step 7
    show_step "${ICON_BUILD} Installing AOSP Dependencies"
    if [[ ! -d "$BUILD_SCRIPTS_DIR" ]]; then
        run_task "Cloning AOSP build scripts" git clone -q --depth=1 https://github.com/akhilnarang/scripts "$BUILD_SCRIPTS_DIR"
    else
        echo -e "  ${C_WHITE}${ICON_ARROW}${C_NC} Build scripts already present [${C_GREEN}${ICON_OK}${C_NC}]"
    fi

    bash "$BUILD_SCRIPTS_DIR/setup/android_build_env.sh" &>/dev/null || echo -e "  ${C_YELLOW}${ICON_WARN} Some optional dependencies failed.${C_NC}"

    # Step 8 (New)
    show_step "${ICON_WARN} Optional Repo Safety Lock"
    setup_repo_safety_lock

    # Step 9
    show_step "${ICON_PACKAGE} Final System Update"
    run_task "Updating package lists" apt-get update -qq
    run_task "Upgrading new packages" apt-get upgrade -qq -y
    run_task "Cleaning package cache" apt-get autoclean -qq -y
    run_task "Removing unused packages" apt-get autoremove -qq -y

    # Final summary
    echo
    echo -e "${C_GREEN}╔══════════════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_GREEN}║${C_NC}                                                          ${C_GREEN}║${C_NC}"
    echo -e "${C_GREEN}║${C_NC}     ${C_WHITE}${ICON_OK} Setup completed successfully!${C_NC}               ${C_GREEN}║${C_NC}"
    echo -e "${C_GREEN}║${C_NC}                                                          ${C_GREEN}║${C_NC}"
    echo -e "${C_GREEN}║${C_NC}     ${C_DIM}Log file:${C_NC} ${C_GRAY}$LOG_FILE${C_NC}"
    echo -e "${C_GREEN}║${C_NC}                                                          ${C_GREEN}║${C_NC}"
    echo -e "${C_GREEN}╚══════════════════════════════════════════════════════════╝${C_NC}"
    echo
    get_system_info
}

main "$@"
