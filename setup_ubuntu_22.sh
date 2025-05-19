#!/bin/bash

# Exit on error and print each command
set -e

echo "==> Updating and upgrading system packages..."
sudo apt update -y && sudo apt upgrade -y

echo "==> Installing required packages..."
sudo apt install unzip -y
sudo apt install tmate -y
sudo apt install git -y
sudo apt install tmux -y
sudo apt install ccache -y
sudo apt install zip -y

# Run another round of update/upgrade
echo "==> Final system update to ensure everything is current..."
sudo apt update -y && sudo apt upgrade -y

echo "==> Downloading Android platform-tools..."
cd ~/
wget -nc https://dl.google.com/android/repository/platform-tools-latest-linux.zip

echo "==> Unzipping platform-tools..."
unzip -o platform-tools-latest-linux.zip -d ~

echo "==> Adding platform-tools to .profile..."
ANDROID_PATH_BLOCK='# add Android SDK platform tools to path
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi'

if ! grep -Fxq '# add Android SDK platform tools to path' ~/.profile; then
    echo -e "\n$ANDROID_PATH_BLOCK" >> ~/.profile
    echo "-> Block added to .profile"
else
    echo "-> Block already exists in .profile"
fi

echo "==> Reloading .profile..."
source ~/.profile

echo "==> Installing build packages using Akhil Narang's script..."
cd ~/
git clone https://github.com/akhilnarang/scripts || echo "-> Repo already cloned"
cd scripts
echo "---- Output from android_build_env.sh ----"
bash setup/android_build_env.sh
echo "---- End of android_build_env.sh output ----"

echo "==> Creating ~/bin directory..."
mkdir -p ~/bin

echo "==> Downloading the repo tool..."
curl -o ~/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
chmod a+x ~/bin/repo

echo "==> Android build environment setup complete!"
