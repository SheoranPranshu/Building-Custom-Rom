sudo apt update && sudo apt upgrade 

sudo apt update && sudo apt install zram-tools

sudo apt install linux-modules-extra-$(uname -r)

lsmod | grep zram

sudo modprobe zram

cd ~/
wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip

unzip platform-tools-latest-linux.zip -d ~

cd ~/
git clone https://github.com/akhilnarang/scripts
cd scripts
./setup/android_build_env.sh

mkdir -p ~/bin

curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
