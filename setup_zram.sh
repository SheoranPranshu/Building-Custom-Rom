#!/usr/bin/env bash
set -e

# 1. Install zram-tools
echo "Installing zram-tools..."
sudo apt update
sudo apt install -y zram-tools

# 2. Configure /etc/default/zramswap
#    Set PERCENT, ALGO, PRIORITY
CONFIG="/etc/default/zramswap"
PERCENT=70
ALGO=zstd
PRIORITY=100

echo "Configuring zramswap..."
sudo sed -i -r \
    -e "s|^#?PERCENT=.*|PERCENT=${PERCENT}|" \
    -e "s|^#?ALGO=.*|ALGO=${ALGO}|" \
    -e "s|^#?PRIORITY=.*|PRIORITY=${PRIORITY}|" \
    "${CONFIG}"

# 3. Install kernel modules extras
echo "Installing linux-modules-extra for current kernel..."
sudo apt install -y "linux-modules-extra-$(uname -r)"

# 4. Load zram module if not already loaded
if ! lsmod | grep -q '^zram'; then
    echo "Loading zram module..."
    sudo modprobe zram
fi

# 5. Restart zramswap service
echo "Restarting zramswap service..."
sudo systemctl restart zramswap

# 6. Show only swapon output
echo
echo "=== swapon --show ==="
swapon --show
