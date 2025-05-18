sudo apt update -y && sudo apt upgrade -y

sudo apt install unzip -y

sudo apt install tmate -y

sudo apt install git -y

sudo apt install tmux -y

sudo apt install ccache -y

sudo apt install zip -y

sudo apt update -y && sudo apt upgrade -y

cd ~/
wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip

unzip platform-tools-latest-linux.zip -d ~

cd ~/
git clone https://github.com/akhilnarang/scripts

./scripts/setup/android_build_env.sh

mkdir -p ~/bin

curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo

sudo apt update -y && sudo apt upgrade -y
chmod a+x ~/bin/repo
