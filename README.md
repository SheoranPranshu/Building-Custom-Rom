
# Android ROM Build Environment Setup

Automated setup scripts for building custom Android ROMs on Ubuntu 22.04 LTS.

## Repository Setup

```bash
git clone https://github.com/sheoranpranshu/Building-Custom-Rom.git build-scripts
cd build-scripts
```

### Environment Installation

Install all required development tools, libraries, and Android platform components:

```bash
sudo ./scripts/setup_build_environment.sh
```

### ZRAM Configuration

Optimize build performance with compressed RAM-based swap:

#### Standard Setup (69% zram, zstd, priority 100)
```bash
sudo ./scripts/setup_zram.sh
```

#### Custom Configuration
```bash
sudo ./scripts/setup_zram.sh -p <percentage> -a <algorithm> -r <priority>
```

#### Example
```bash
sudo ./scripts/setup_zram.sh -p 100 -a zstd -r 100
```

## Credits & Acknowledgements

Special thanks to:
- [LineageOS](https://github.com/lineageos)
- [Akhil Narang](https://github.com/akhilnarang)
