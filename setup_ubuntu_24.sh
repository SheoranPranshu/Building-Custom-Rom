# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root"
    exit
fi

sudo apt update
sudo apt upgrade -y

PACKAGES="bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev libelf-dev liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev gh iotop bashtop nethogs autossh apache2 p7zip neofetch gettext autoconf automake libtool make gcc autopoint patchelf python-is-python3 clang lld llvm gcc gcc-multilib zsh openjdk-17-jdk openjdk-17-jre xmlstarlet micro "

sudo apt install -y $PACKAGES

# Install ncurses5
wget http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb && sudo dpkg -i libtinfo5_6.3-2_amd64.deb && rm -f libtinfo5_6.3-2_amd64.deb
wget http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb && sudo dpkg -i libncurses5_6.3-2_amd64.deb && rm -f libncurses5_6.3-2_amd64.deb

# Install repo
sudo curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/bin/repo
sudo chmod a+x /usr/bin/repo

# Disable the apparmor using sysctl
echo 'kernel.apparmor_restrict_unprivileged_userns = 0' | 
  sudo tee /etc/sysctl.d/20-apparmor-donotrestrict.conf

sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
