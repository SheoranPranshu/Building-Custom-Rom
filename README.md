# Environment Setup Guide

## Repository Setup

Clone the configuration repository and navigate to the build scripts directory:

```bash
git clone https://github.com/sheoranpranshu/Building-Custom-Rom.git build-scripts
cd build-scripts
```

## Environment Installation

The setup script is to install all required development tools, libraries, and Android platform components Ubuntu 22.04 LTS

```bash
sudo ./scripts/setup_build_environment.sh
```

## ZRAM Configuration

ZRAM creates compressed swap space in memory, significantly improving build performance through reduced disk operations and faster compilation times.

### Standard Setup

Deploy ZRAM with optimized defaults (69% RAM allocation, ZSTD compression):

```bash
sudo ./scripts/setup_zram.sh
```

### Custom Configuration

Configure specific parameters for specialized requirements:

```bash
sudo ./scripts/setup_zram.sh -p <percentage> -a <algorithm> -r <priority>
```

Available algorithms include lzo, lz4, and zstd. Percentage values range from 10-100% of available memory.

### Recommendation

For maximum performance in high-resource environments:

```bash
sudo ./scripts/setup_zram.sh -p 100 -a zstd -r 100
```

