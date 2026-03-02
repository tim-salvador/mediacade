# RetroPie-X86 Setup for Ubuntu 24.04 LTS

A modern, fully automated RetroPie installation for x86-64 PCs running Ubuntu 24.04 LTS.  
Forked from and inspired by [MizterB/RetroPie-Setup-Ubuntu](https://github.com/MizterB/RetroPie-Setup-Ubuntu), modernized for 2024+.

---

## ✨ Features

| Feature | Details |
|---|---|
| **OS** | Ubuntu 24.04 LTS (Noble Numbat) — minimal server base |
| **Window Manager** | OpenBox → EmulationStation (no desktop environment) |
| **Video Drivers** | Auto-detected: Intel i915/xe, NVIDIA proprietary, Vulkan (Mesa + NVIDIA) |
| **Autologin** | TTY → OpenBox → EmulationStation, no user interaction required |
| **Splash Screen** | Plymouth with selectable themes from HerbFargus collection |
| **Boot** | Silent GRUB + silent kernel (no text output during boot/shutdown) |
| **Display** | Forced 1080p for GRUB + Xorg (configurable, optimized for 4K panels) |
| **NFS** | Server + client; ROMs directory shared and auto-mounted via fstab |
| **RetroPie** | Full installation with pre-configured emulator settings |
| **Flycast** | `lr-flycast` installed and configured (Dreamcast/NAOMI/NAOMI2/AtomisWave) |
| **Mouse** | `unclutter` — cursor hidden when idle, visible on movement |
| **Terminal** | Chromeless terminal (no scrollbar, menu, or cursor) for emulator launches |
| **Sudo** | Passwordless sudo for the retropie user |

---

## 🖥️ Requirements

- x86-64 PC (UEFI or Legacy BIOS supported)
- Ubuntu **24.04 LTS** fresh minimal install (server ISO recommended)
- Internet connection
- GPU: Intel (Gen 6+), NVIDIA (Kepler+), or AMD (uses Mesa — see notes)
- 20 GB minimum disk space (50 GB+ recommended for ROMs)

---

## 🚀 Quick Start

### Step 1 — Install Ubuntu 24.04 LTS

1. Download the [Ubuntu 24.04 LTS Server ISO](https://releases.ubuntu.com/24.04/)
2. Flash to USB using [Balena Etcher](https://etcher.balena.io/) or `dd`
3. Boot and complete a **minimal server install**:
   - Set username: `pi` (or edit `retropie.cfg` after cloning)
   - No desktop environment — server base only
   - Enable OpenSSH for remote setup (optional but recommended)

### Step 2 — Clone & Configure

```bash
git clone https://github.com/YOUR_USERNAME/retropie-x86.git
cd retropie-x86
cp retropie.cfg.example retropie.cfg
nano retropie.cfg   # Edit your settings
```

### Step 3 — Run the Installer

```bash
chmod +x install.sh
sudo ./install.sh
```

The installer is **modular** — each script in `scripts/` can be run independently for maintenance or re-runs.

---

## ⚙️ Configuration (`retropie.cfg`)

```bash
# User that will run EmulationStation / RetroPie
RETROPIE_USER="pi"

# GPU driver to install: auto | intel | nvidia | none
GPU_DRIVER="auto"

# Target display resolution for GRUB and Xorg
DISPLAY_WIDTH=1920
DISPLAY_HEIGHT=1080
DISPLAY_DEPTH=24
DISPLAY_REFRESH=60

# Plymouth splash theme (see docs/SPLASH_THEMES.md for options)
PLYMOUTH_THEME="retrowave"

# NFS ROMs share
NFS_SERVER_IP=""              # Leave blank to act as server only
NFS_ROMS_PATH="/home/pi/RetroPie/roms"
NFS_EXPORT_SUBNET="192.168.1.0/24"
NFS_MOUNT_OPTIONS="rw,sync,hard,intr"

# Skip modules (space-separated): e.g. "nvidia nfs flycast"
SKIP_MODULES=""
```

---

## 📁 Repository Structure

```
retropie-x86/
├── install.sh                  # Main entry point
├── retropie.cfg.example        # Config template
├── scripts/
│   ├── 00-preflight.sh         # Checks & prerequisites
│   ├── 01-system-prep.sh       # Sudoers, base packages, locale
│   ├── 02-dependencies.sh      # Xorg, OpenBox, minimal GUI stack
│   ├── 03-video-drivers.sh     # Intel/NVIDIA/Vulkan drivers
│   ├── 04-autologin.sh         # TTY autologin → Openbox → ES
│   ├── 05-grub-splash.sh       # Silent GRUB + 1080p framebuffer
│   ├── 06-plymouth.sh          # Plymouth + HerbFargus themes
│   ├── 07-openbox.sh           # OpenBox config + unclutter
│   ├── 08-nfs.sh               # NFS server/client + fstab
│   ├── 09-retropie.sh          # RetroPie installation
│   ├── 10-flycast.sh           # lr-flycast build & configure
│   └── 11-emulator-config.sh   # Pre-built emulator configs
├── configs/
│   ├── openbox/                # autostart, rc.xml, menu.xml
│   ├── retropie/               # ES configs, themes, gamelist
│   └── emulators/
│       ├── retroarch/          # retroarch.cfg base config
│       └── flycast/            # emu_general.data, mappings
├── docs/
│   ├── INSTALL.md              # Detailed install walkthrough
│   ├── SPLASH_THEMES.md        # Plymouth theme reference
│   ├── NFS_SETUP.md            # NFS server/client details
│   └── TROUBLESHOOTING.md      # Common issues & fixes
└── assets/
    └── plymouth-themes/        # Submodule: HerbFargus themes
```

---

## 📖 Documentation

- [Detailed Installation Guide](docs/INSTALL.md)
- [Splash Screen Themes](docs/SPLASH_THEMES.md)
- [NFS ROMs Share Setup](docs/NFS_SETUP.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

---

## 🔧 Individual Module Usage

```bash
# Re-run a specific module
sudo ./scripts/03-video-drivers.sh

# Change splash theme after install
sudo PLYMOUTH_THEME="pacman" ./scripts/06-plymouth.sh

# Re-apply emulator configs
sudo ./scripts/11-emulator-config.sh
```

---

## Credits

- [MizterB](https://github.com/MizterB) — original RetroPie-Setup-Ubuntu
- [RetroPie Project](https://retropie.org.uk/)
- [HerbFargus](https://github.com/HerbFargus/plymouth-themes) — Plymouth themes
- [Libretro](https://www.libretro.com/) — lr-flycast
