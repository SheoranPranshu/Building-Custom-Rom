#!/usr/bin/env bash

#
# Universal Android Build Environment Setup
# Configures Debian/Ubuntu systems for AOSP builds.
#

set -e

C_BLUE='\033[1;34m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_NC='\033[0m'

print_status() {
    echo -e "${C_BLUE}[INFO]${C_NC} $1"
}

print_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"
}

print_warning() {
    echo -e "${C_YELLOW}[WARNING]${C_NC} $1"
}

print_error() {
    echo -e "${C_RED}[ERROR]${C_NC} $1" >&2
}

detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
        print_status "Detected system: $PRETTY_NAME"
    else
        print_error "Unable to detect operating system"
        exit 1
    fi
}

install_base_packages() {
    print_status "Updating package repositories"
    sudo apt update

    print_status "Upgrading existing packages"
    sudo apt upgrade -y

    print_status "Installing base development tools"
    sudo apt install -y \
        openssh-server screen python3 git default-jdk android-tools-adb bc bison \
        build-essential curl flex g++-multilib gcc-multilib gnupg gperf imagemagick \
        lib32ncurses-dev lib32readline-dev lib32z1-dev lz4 libncurses5-dev libsdl1.2-dev \
        libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools \
        xsltproc yasm zip zlib1g-dev libtinfo5 libncurses5 unzip tmate ccache

    print_success "Base packages installation completed"
}

setup_python2() {
    if command -v python2 &> /dev/null; then
        print_status "Python 2 is already available"
        return 0
    fi

    print_status "Python 2 not found, installing from source"
    cd /tmp
    
    if [ ! -f "Python-2.7.18.tgz" ]; then
        print_status "Downloading Python 2.7.18"
        wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
    fi
    
    print_status "Extracting Python 2.7.18"
    tar xzf Python-2.7.18.tgz
    cd Python-2.7.18
    
    print_status "Configuring Python 2.7.18 build"
    ./configure --enable-optimizations
    
    print_status "Building and installing Python 2.7.18"
    make -j$(nproc)
    sudo make altinstall
    
    print_status "Creating Python 2 symbolic link"
    sudo ln -sfn '/usr/local/bin/python2.7' '/usr/bin/python2'
    
    cd "$HOME"
    print_success "Python 2 installation completed"
}

setup_android_tools() {
    print_status "Setting up Android platform tools"
    cd "$HOME"
    
    if [ ! -f "platform-tools-latest-linux.zip" ]; then
        print_status "Downloading Android platform tools"
        wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
    fi
    
    if [ ! -d "platform-tools" ]; then
        print_status "Extracting platform tools"
        unzip -q platform-tools-latest-linux.zip
    fi
    
    print_status "Configuring PATH for platform tools"
    local android_path_block='
# Android SDK platform tools
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi'
    
    if ! grep -q 'PATH="$HOME/platform-tools:$PATH"' ~/.profile; then
        echo "$android_path_block" >> ~/.profile
        print_success "Added platform tools to PATH in .profile"
    else
        print_status "Platform tools already configured in PATH"
    fi
    
    print_success "Android platform tools setup completed"
}

setup_repo_tool() {
    print_status "Setting up repo tool"
    mkdir -p ~/bin
    
    if [ ! -f ~/bin/repo ]; then
        print_status "Downloading repo tool"
        curl -o ~/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
        chmod a+x ~/bin/repo
        print_success "Repo tool installed"
    else
        print_status "Repo tool already installed"
    fi
    
    local bin_path_block='
# User bin directory
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi'
    
    if ! grep -q 'PATH="$HOME/bin:$PATH"' ~/.profile; then
        echo "$bin_path_block" >> ~/.profile
        print_success "Added ~/bin to PATH in .profile"
    else
        print_status "~/bin already configured in PATH"
    fi
}

setup_build_environment() {
    print_status "Setting up AOSP build environment"
    cd "$HOME"
    
    if [ ! -d "scripts" ]; then
        print_status "Cloning build environment scripts"
        git clone https://github.com/akhilnarang/scripts.git
    else
        print_status "Build environment scripts already present"
        cd scripts
        print_status "Updating build environment scripts"
        git pull
        cd "$HOME"
    fi
    
    print_status "Running Android build environment setup"
    cd scripts
    bash setup/android_build_env.sh
    cd "$HOME"
    
    print_success "AOSP build environment setup completed"
}

main() {
    echo -e "${C_BLUE}Android Build Environment Setup${C_NC}"
    echo "========================================"
    
    print_status "Requesting sudo access for package installation"
    sudo -v
    
    while true; do 
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
    
    detect_system
    
    print_status "Phase 1: Installing system packages"
    install_base_packages
    
    print_status "Phase 2: Setting up Python 2"
    setup_python2
    
    print_status "Phase 3: Installing Android tools"
    setup_android_tools
    
    print_status "Phase 4: Setting up repo tool"
    setup_repo_tool
    
    print_status "Phase 5: Configuring build environment"
    setup_build_environment
    
    echo
    echo "========================================"
    print_success "Android build environment setup completed successfully"
    echo
    print_warning "To activate PATH changes, either:"
    echo "  1. Open a new terminal session"
    echo "  2. Run: source ~/.profile"
    echo
    print_status "Your system is now ready for Android ROM development"
}

main "$@"
