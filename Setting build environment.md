## Let's begin
## 1. Download and install platform-tools

Download the platform-tools for Linux from here by using the terminal.
```bash
cd ~/
wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
```
Use this command to unzip it:
```bash
unzip platform-tools-latest-linux.zip -d ~
```
Now you have to add adb and fastboot to your PATH. In the same terminal enter this:
```bash
cd ~/
nano ~/.profile
```
Just enter the following text at the bottom of the file that opens up, save it and close.
```bash
# add Android SDK platform tools to path
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi
```
Key combination to save file and exit in nano editor is: (Ctrl + O) + (Enter) + (Ctrl + X). 
Then, run this to update your environment.
```bash
source ~/.profile
```
## 2. Install the build packages
Several packages are needed to build a Custom ROM and all those can be installed easily by using Akhil Narang's scripts. Run this:
```bash
cd ~/
git clone https://github.com/akhilnarang/scripts
cd scripts
./setup/android_build_env.sh
```
## 3. Create the directories
You’ll need to set up some directories in your build environment
To create them:
```bash
mkdir -p ~/bin
mkdir -p ~/(romname)
```
The ~/bin directory will contain the git-repo tool (commonly named “repo”) and the ~/android directory will contain the source code of the Custom ROM


## 4. Install the repo command
Enter the following to download the repo binary and make it executable (runnable):
```bash
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
```
## 5. Configure git
Given that repo requires you to identify yourself to sync Android, run the following commands to configure your git identity:
```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

- [Akhil Narang](https://github.com/akhilnarang)
