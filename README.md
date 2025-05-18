# For Ubuntu 22

- Execute setup file.

```bash
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup_ubuntu_22.sh && chmod +x setup_ubuntu_22.sh && ./setup_ubuntu_22.sh
```

- After this

```bash
cd ~/
nano ~/.profile
```

- Just enter the following text at the bottom of the file that opens up, save it and close.

```bash
# add Android SDK platform tools to path
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi
```
- Key combination to save file and exit in nano editor is: (Ctrl + O) + (Enter) + (Ctrl + X). 
    - Then, run this to update your environment.

```bash
source ~/.profile
```
- You are now good to go!!

# For Ubuntu 24
```
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup_ubuntu_24.sh && chmod +x setup_ubuntu_24.sh && sudo ./setup_ubuntu_24.sh
```
