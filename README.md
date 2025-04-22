# Just copy paste as below 

```
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup.sh && chmod +x setup.sh && ./setup.sh
```

After this

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
