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

Configure Zram
```
sudo nano /etc/default/zramswap
```
change the things as below/per requirement 

PERCENT=75

ALGO=zstd

PRIORITY=100

change the things in that file like above and remove '#' before PERCENT/ALGO/PRIORITY

you can lz4 aslo for ALGO instead of zstd

Percent is how much zram you want like here 75 percent of my ram i.e, like 24 gb for 32gb physical ram

 Start Zram (if fails do further steps)
```
sudo systemctl restart zramswap
```
if done then zram is started successfully no need to go further 

Check Zram
```
swapon --show
```
