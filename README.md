- Execute setup file.

```
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup_build_environment.sh && chmod +x setup_build_environment.sh && ./setup_build_environment.sh
```

- After this

```
cd ~/
nano ~/.profile
```

Just enter the following text at the bottom of the file that opens up, save it and close.
```
# add Android SDK platform tools to path
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi
```
- Key combination to save file and exit in nano editor is: (Ctrl + O) + (Enter) + (Ctrl + X). 
    - Then, run this to update your environment.

```
source ~/.profile
```
- You are now good to go!!
