# 1) Now lets setup zram for faster works
we should setup zram less than the physical memory 

# 2) Install Zram Tools
```
sudo apt update && sudo apt install zram-tools
```
# 3) Configure Zram
```
sudo nano /etc/default/zramswap
```
change the things as below/per requirement 

PERCENT=75

ALGO=lz4

PRIORITY=100

change the things in that file like above and remove '#' before PERCENT/ALGO/PRIORITY

Percent is how much zram you want like here 75 percent of my ram i.e, like 24 gb for 32gb physical ram

# 4) Start Zram
```
sudo systemctl restart zramswap
```
if done then zram is started successfully no need to go further 

# 5) Check Zram
```
free-h
```

# 6) If fails or dont show zram then do like this
```
lsmod | grep zram
```       
- Should show "zram"
- Load manually if missing
```
sudo modprobe zram
```

after above steps

# 7) Install kernel modules (Ubuntu 22.04)
```
sudo apt install linux-modules-extra-$(uname -r)
```
# 8) now start again
```
sudo systemctl restart zramswap
```

# 9) check zram
```
free-h
```

# if still fails then do step 7 then 6 then 8 it will work now 
if not search on google I only found these solutions

