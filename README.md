Got it! Here is a simpler and more direct version.

---

# 🚀 **Custom ROM Build Environment Setup**

### 🐧 **For Ubuntu 22.04 LTS**
```bash
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup_ubuntu_22.sh && chmod +x setup_ubuntu_22.sh && ./setup_ubuntu_22.sh && rm setup_ubuntu_22.sh
```

### ✨ **For Ubuntu 24.04 LTS**
```bash
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup_ubuntu_24.sh && chmod +x setup_ubuntu_24.sh && sudo ./setup_ubuntu_24.sh && rm setup_ubuntu_24.sh
```

### 🧠 **Setup ZRAM (70% of RAM)**
*This is a recommended performance boost for building.*
```bash
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup_zram.sh && chmod +x setup_zram.sh
```
- For running as Usual
```
sudo ./setup_zram.sh
```
- For running with manual settings
```
sudo ./setup_zram.sh -p <percent> -a <algorithm> -r <priority>
```
- Flags:  
  - -p – size as % of RAM (e.g. -p 50)
  - -a – compression algo (e.g. -a lzo/lz4/zstd)
  - -r – swap priority (e.g. -r 100)
 
eg:
```
sudo ./setup_zram.sh -p 80 -a lzo -r 100
```

---

**Happy Building! 🛠️🔥**
