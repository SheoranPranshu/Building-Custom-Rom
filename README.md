# Android ROM Development Environment Setup

This guide establishes a complete Android ROM development environment with ZRAM optimization.

## Repository Setup

Create a workspace and clone the configuration repository:

```bash
git clone https://github.com/sheoranpranshu/Building-Custom-Rom.git build-scripts
cd build-scripts
```

## Environment Installation

### Ubuntu 22.x and Debian 12.x

Execute the primary setup script for stable distributions:

```bash
chmod +x scripts/setup_build_environment.sh
sudo ./scripts/setup_build_environment.sh
```

### Ubuntu 24.04 LTS (Experimental)

For Ubuntu 24.04 LTS systems, use the experimental configuration:

```bash
chmod +x scripts/setup_ubuntu_24.sh
sudo ./scripts/setup_ubuntu_24.sh
```

## ZRAM Configuration

ZRAM improves build performance by creating compressed swap space in memory. The default configuration allocates 70% of system RAM.

### Standard Setup

```bash
chmod +x scripts/setup_zram.sh
sudo ./scripts/setup_zram.sh
```

### Custom Configuration

```bash
sudo ./scripts/setup_zram.sh -p <percentage> -a <algorithm> -r <priority>
```

Configuration options include percentage of RAM allocation, compression algorithm selection (lzo, lz4, zstd), and swap priority settings.

### Recommended Production Setup

```bash
sudo ./scripts/setup_zram.sh -p 100 -a zstd -r 100
```

The environment is now ready for Android ROM development with optimized memory management.
