- This is a simple guide to setup ZRAM.
  - First of all we should setup zram less than the physical memory 

1. Install Zram Tools.
```
sudo apt update && sudo apt install zram-tools
```

2. Configure Zram.
```
sudo nano /etc/default/zramswap
```

3. Change the things as per requirement.

- Change accordingly
  - PERCENT=75
  - ALGO=zstd
  - PRIORITY=100

- Change the things in that file like above and remove '#' before PERCENT/ALGO/PRIORITY.

- You can lz4 aslo for ALGO instead of zstd.

- Percent is how much zram you want like here 75 percent of my ram i.e, like 24 gb for 32gb physical ram.

4. Start Zram (if fails do further steps).
```
sudo systemctl restart zramswap
```
If done then zram is started successfully no need to go further.

5.  Check Zram.
```
swapon --show
```

6. If fails or doesn't show zram then do further steps.

7. Installing kernel modules.
```
sudo apt install linux-modules-extra-$(uname -r)
```

8. Loading Zram Manually.
```
lsmod | grep zram
```       
- Should show "zram".

 9. Load manually if missing.
```
sudo modprobe zram
```

10. Now start zram again.
```
sudo systemctl restart zramswap
```

11. Check zram.
```
swapon --show
```

12. *If still fails then google the error, I can't help you*.

