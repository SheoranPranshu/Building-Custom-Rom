# Custom ROM Build Environment Setup

Set up a complete Android ROM development environment with ZRAM optimization on Ubuntu.

---

## Ubuntu 22.04 LTS Setup

```bash
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup_ubuntu_22.sh \
  && chmod +x setup_ubuntu_22.sh \
  && ./setup_ubuntu_22.sh \
  && rm setup_ubuntu_22.sh
```

---

## Ubuntu 24.04 LTS Setup (Experimental)

> Note: This script is currently unstable and may not work as expected.

```bash
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup_ubuntu_24.sh \
  && chmod +x setup_ubuntu_24.sh \
  && sudo ./setup_ubuntu_24.sh \
  && rm setup_ubuntu_24.sh
```

---

## ZRAM Setup (Recommended for Performance)

Optimize memory usage by enabling ZRAM with 70% of your system's RAM:

### Download Script

```bash
wget https://github.com/glitch-wraith/Building-Custom-Rom/raw/refs/heads/main/setup_zram.sh \
  && chmod +x setup_zram.sh
```

### Run with Default Settings

```bash
sudo ./setup_zram.sh
```

### Run with Custom Settings

```bash
sudo ./setup_zram.sh -p <percent> -a <algorithm> -r <priority>
```

#### Flags:

* `-p` — Size as % of total RAM (e.g., `-p 70`)
* `-a` — Compression algorithm (`lzo`, `lz4`, `zstd`)
* `-r` — Swap priority (e.g., `-r 100`)

#### Example:

```bash
sudo ./setup_zram.sh -p 80 -a lzo -r 100
```

---

## Happy Building!
