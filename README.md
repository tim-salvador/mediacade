<div align="center">

# mediacade

### A modern, fully automated RetroPie setup for x86-64 PCs on Ubuntu 24.04 LTS

[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://releases.ubuntu.com/24.04/)
[![RetroPie](https://img.shields.io/badge/RetroPie-4.x-blue?logo=data:image/png;base64,)](https://retropie.org.uk/)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Forked from MizterB](https://img.shields.io/badge/Forked%20from-MizterB%2FRetroPie--Setup--Ubuntu-8A2BE2)](https://github.com/MizterB/RetroPie-Setup-Ubuntu)

*Forked from and inspired by [MizterB/RetroPie-Setup-Ubuntu](https://github.com/MizterB/RetroPie-Setup-Ubuntu) — modernized for 2025+*

</div>

---

## Overview

mediacade transforms a bare Ubuntu 24.04 LTS server install into a dedicated retro gaming console — no desktop environment, no display manager, no bloat. It boots silently and directly into EmulationStation, drives the latest Intel, NVIDIA, and Vulkan GPU stacks, shares your ROM library over NFS, and gets out of your way.

Everything is controlled from a single config file (`retropie.cfg`) and broken into 12 independent, re-runnable modules.

---

## Boot Flow

```
Power On
   │
   ▼
GRUB  ──── timeout=0, hidden, 1080p framebuffer, silent kernel cmdline
   │
   ▼
Plymouth ──── animated splash (selectable HerbFargus theme)
   │
   ▼
systemd ──── multi-user.target (no display manager)
   │
   ▼
getty@tty1 ──── autologin as ${RETROPIE_USER}
   │
   ▼
.bash_profile ──── detects TTY1 → exec startx
   │
   ▼
.xinitrc ──── xset (no blank), xrandr (1080p), unclutter, pulseaudio
   │
   ▼
openbox-session ──── autostart script
   │
   ▼
EmulationStation ──── full-screen, no window chrome
```

---

## Features

| Category | What's included |
|---|---|
| **OS Base** | Ubuntu 24.04 LTS minimal server — no desktop, no display manager |
| **GPU: Intel** | Mesa iris/xe driver, modesetting Xorg, ANV Vulkan (Mesa), VA-API |
| **GPU: NVIDIA** | Auto-detected proprietary driver via `ubuntu-drivers`, Nouveau blacklisted, Vulkan ICD |
| **GPU: AMD** | Mesa radeonsi, RADV Vulkan, amdgpu Xorg driver |
| **Vulkan** | `vulkan-tools`, `mesa-vulkan-drivers`, `spirv-tools`, `glslang-tools` installed for all GPU types |
| **Window Manager** | OpenBox — minimal WM, no compositor, full-screen rules for ES and RetroArch |
| **Autologin** | `systemd getty` override → `.bash_profile` → `startx` → OpenBox → EmulationStation |
| **Display** | 1080p forced at GRUB (framebuffer) and Xorg (xrandr) — configurable, ideal for 4K panels |
| **Boot Silence** | `quiet splash loglevel=3 vt.global_cursor_default=0` + `GRUB_TIMEOUT=0` + `GRUB_GFXPAYLOAD=keep` |
| **Splash Screens** | Full [HerbFargus plymouth-themes](https://github.com/HerbFargus/plymouth-themes) collection installed; selectable with a helper command |
| **Terminal** | `xterm` configured chromeless — no scrollbar, no menu bar, no cursor, no title |
| **Mouse Cursor** | `unclutter` hides cursor after configurable idle timeout; reappears on movement |
| **Passwordless sudo** | `/etc/sudoers.d/` drop-in for the retropie user — no password prompts |
| **NFS** | `nfs-kernel-server` + `nfs-common`; ROMs exported/mounted; fstab with `x-systemd.automount` |
| **RetroPie** | Full install via official RetroPie-Setup; core + common emulator packages |
| **lr-flycast** | Binary install with source-build fallback (Dreamcast / NAOMI / NAOMI2 / AtomisWave) |
| **Emulator Config** | Pre-tuned `retroarch.cfg` (hotkeys, audio, video, paths) + per-system overrides |

---

## Requirements

| | Minimum | Recommended |
|---|---|---|
| **Architecture** | x86-64 | x86-64 |
| **OS** | Ubuntu 24.04 LTS (Server) | Ubuntu 24.04 LTS (Server, minimized) |
| **RAM** | 1 GB | 4 GB+ |
| **Storage** | 20 GB | 100 GB+ (for ROMs) |
| **GPU** | Intel Gen 6 / NVIDIA Kepler / AMD GCN | Intel Gen 9+ / NVIDIA Maxwell+ / AMD Polaris+ |
| **Network** | Required for install | Gigabit Ethernet (for NFS ROMs) |

> **GPU note:** AMD is supported via open-source Mesa (`radeonsi` + `RADV`). No proprietary AMD driver is installed. Performance is excellent on GCN and later.

---

## Quick Start

### 1. Install Ubuntu 24.04 LTS

Download the **Server ISO** (leaner than Desktop):  
👉 https://releases.ubuntu.com/24.04/

Flash to USB:
```bash
# Linux / macOS
sudo dd if=ubuntu-24.04.x-live-server-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
*Windows: use [Rufus](https://rufus.ie) or [Balena Etcher](https://etcher.balena.io/)*

**During the Ubuntu installer:**
- Choose **Ubuntu Server (minimized)**
- Set your username (default assumed: `pi`)
- ✅ Enable **OpenSSH server**
- ❌ Skip all Featured Snaps
- ❌ Do **not** install Ubuntu Desktop

### 2. Clone & Configure

```bash
# Install git if missing (minimal installs sometimes omit it)
sudo apt-get install -y git

git clone https://github.com/YOUR_USERNAME/mediacade.git
cd mediacade

cp retropie.cfg.example retropie.cfg
nano retropie.cfg
```

### 3. Run the Installer

```bash
chmod +x install.sh
sudo ./install.sh
```

> ⏱️ Expect **20–60 minutes** depending on CPU speed, RAM, and internet connection.  
> The log is written to `/var/log/mediacade-install.log`.

### 4. Reboot

```bash
sudo reboot
```

The system will boot silently and launch EmulationStation automatically.

---

## Configuration Reference

All options live in `retropie.cfg`. Copy from `retropie.cfg.example` and edit before running the installer.

```bash
# ── User ─────────────────────────────────────────────────────────────────────
RETROPIE_USER="pi"            # Must already exist on the system

# ── GPU ──────────────────────────────────────────────────────────────────────
GPU_DRIVER="auto"             # auto | intel | nvidia | amd | none

# ── Display ───────────────────────────────────────────────────────────────────
DISPLAY_WIDTH=1920            # GRUB framebuffer + Xorg resolution
DISPLAY_HEIGHT=1080
DISPLAY_DEPTH=24
DISPLAY_REFRESH=60
DISPLAY_OUTPUT=""             # e.g. "HDMI-1" — blank = auto-detect

# ── Splash Screen ─────────────────────────────────────────────────────────────
PLYMOUTH_THEME="retrowave"    # See docs/SPLASH_THEMES.md for full list

# ── NFS ───────────────────────────────────────────────────────────────────────
NFS_ROLE="server"             # server | client | both | none
NFS_SERVER_IP=""              # Client mode: IP of the NFS server
NFS_ROMS_PATH="/home/pi/RetroPie/roms"
NFS_EXPORT_SUBNET="192.168.1.0/24"
NFS_MOUNT_OPTIONS="rw,sync,hard,intr,timeo=14"

# ── Optional ──────────────────────────────────────────────────────────────────
INSTALL_FLYCAST=true
RETROPIE_EXTRA_PACKAGES=""    # Space-separated extra RetroPie packages
SKIP_MODULES=""               # e.g. "03 08" to skip video drivers + NFS
UNCLUTTER_TIMEOUT=3           # Seconds before mouse cursor hides
KEEP_BUILD_ARTIFACTS=false
MAKE_JOBS=""                  # Parallel compile jobs (blank = nproc)
```

---

## Module Reference

Each script in `scripts/` is independently runnable. Re-run any module after changing config:

```bash
sudo ./scripts/03-video-drivers.sh
```

| # | Script | Responsibility |
|---|---|---|
| 00 | `00-preflight.sh` | OS/arch check, internet, disk space, RAM, GPU auto-detection |
| 01 | `01-system-prep.sh` | Passwordless sudo, APT tuning, locale, base packages, user groups |
| 02 | `02-dependencies.sh` | Xorg, OpenBox, SDL2, GLES/Mesa, unclutter, fonts, Xorg 1080p config |
| 03 | `03-video-drivers.sh` | Intel (modesetting + ANV Vulkan), NVIDIA (proprietary + Nouveau blacklist), AMD (Mesa + RADV), common Vulkan runtime |
| 04 | `04-autologin.sh` | systemd getty override, `.bash_profile` auto-`startx`, `.xinitrc` |
| 05 | `05-grub-splash.sh` | Silent GRUB config, 1080p framebuffer, kernel cmdline, initramfs DRM modules |
| 06 | `06-plymouth.sh` | HerbFargus theme installation, theme activation, `retropie-set-splash` helper |
| 07 | `07-openbox.sh` | `autostart`, `rc.xml` (no decorations), `menu.xml`, chromeless `.Xresources` |
| 08 | `08-nfs.sh` | nfs-kernel-server + nfs-common, `/etc/exports`, fstab with systemd automount |
| 09 | `09-retropie.sh` | RetroPie-Setup clone, core + emulator binary installs, directory structure |
| 10 | `10-flycast.sh` | lr-flycast binary install → source fallback (Vulkan+OpenGL), BIOS dir, emulators.cfg |
| 11 | `11-emulator-config.sh` | `retroarch.cfg` (full config), ES `es_settings.cfg`, per-system overrides |

---

## Splash Screen Themes

All themes from the [HerbFargus/plymouth-themes](https://github.com/HerbFargus/plymouth-themes) collection are installed automatically.

**Change theme at any time:**
```bash
# List all installed themes (current theme marked with →)
sudo retropie-set-splash

# Apply a theme
sudo retropie-set-splash retrowave

# Apply and reboot
sudo retropie-set-splash pacman && sudo reboot
```

**Or during setup**, set in `retropie.cfg`:
```bash
PLYMOUTH_THEME="retrowave"
```

See [docs/SPLASH_THEMES.md](docs/SPLASH_THEMES.md) for the full theme list and how to install custom themes.

---

## NFS ROMs Sharing

mediacade supports a flexible NFS setup for sharing ROMs across multiple machines.

**Server** — this machine hosts and exports ROMs:
```bash
NFS_ROLE="server"
NFS_EXPORT_SUBNET="192.168.1.0/24"
```

**Client** — this machine mounts ROMs from another:
```bash
NFS_ROLE="client"
NFS_SERVER_IP="192.168.1.100"
```

**Both** — NAS-style (share and mount simultaneously):
```bash
NFS_ROLE="both"
```

The fstab entry uses `x-systemd.automount` so the system boots normally even if the NFS server is offline. The mount reconnects automatically when the server becomes available.

See [docs/NFS_SETUP.md](docs/NFS_SETUP.md) for firewall rules, manual mount testing, and multi-client setups.

---

## RetroArch Hotkeys

Default hotkeys use **Select** as the enable button. All combos are configurable in `retroarch.cfg`.

| Combo | Action |
|---|---|
| `Select + Start` | ❌ Exit emulator |
| `Select + B` | 🎛️ Open RetroArch menu |
| `Select + L1` | 💾 Save state |
| `Select + L2` | 📂 Load state |
| `Select + R1` | ⏭️ Next save slot |
| `Select + R2` | ⏮️ Previous save slot |
| `Select + A` | 🔄 Reset game |
| `Select + Y` | ⏸️ Pause |
| `Select + X` | 📸 Screenshot |
| `Select + R1` *(hold)* | ⚡ Fast forward |
| `Escape` | ❌ Exit (keyboard fallback) |

---

## BIOS Files

Place BIOS files in `~/RetroPie/BIOS/` before launching BIOS-dependent systems.

| System | File(s) | Notes |
|---|---|---|
| **PlayStation 1** | `scph1001.bin` | MD5: `924e392ed05558ffdb115408c263dccf` |
| **Dreamcast** | `dc/dc_boot.bin`<br>`dc/dc_flash.bin` | Both required for lr-flycast |
| **NAOMI** | `naomi.zip` | Place in BIOS root |
| **AtomisWave** | `airlbios.zip` | Place in BIOS root |
| **Saturn** | `sega_101.bin` | Or `mpr-17933.bin` (EU/US) |
| **GBA** | `gba_bios.bin` | MD5: `a860e8c0b6d573d191e4ec7db1b1e4f6` |
| **PC Engine CD** | `syscard3.pce` | |
| **Neo Geo** | `neogeo.zip` | Place in ROM directory, not BIOS |

> BIOS files are copyrighted. You must legally own the hardware to use BIOS dumps.

---

## ROM Directory Layout

```
~/RetroPie/roms/
├── nes/
├── snes/
├── n64/
├── gba/          ← Game Boy Advance (.gba)
├── gbc/          ← Game Boy Color (.gbc)
├── gb/           ← Game Boy (.gb)
├── genesis/      ← Sega Genesis/Mega Drive (.md .bin .smd)
├── megacd/       ← Sega CD (.iso .chd .cue)
├── sega32x/      ← 32X (.32x .bin)
├── psx/          ← PlayStation 1 (.iso .bin .cue .chd .pbp)
├── psp/          ← PSP (.iso .cso .pbp)
├── dreamcast/    ← Dreamcast (.cdi .chd .gdi) ← lr-flycast
├── naomi/        ← NAOMI (.zip .7z) ← lr-flycast
├── naomi2/       ← NAOMI 2 (.zip .7z) ← lr-flycast
├── atomiswave/   ← AtomisWave (.zip .7z) ← lr-flycast
├── arcade/       ← FBNeo / MAME ROMs
├── mame-libretro/
├── dos/          ← DOSBox Pure (.zip with exe inside)
├── scummvm/      ← ScummVM games (folder per game)
├── c64/          ← Commodore 64 (.d64 .t64 .prg)
└── ...
```

---

## Repository Structure

```
mediacade/
├── install.sh                    ← Main entry point
├── retropie.cfg.example          ← Config template (copy → retropie.cfg)
├── .gitmodules                   ← HerbFargus themes as git submodule
│
├── scripts/
│   ├── 00-preflight.sh
│   ├── 01-system-prep.sh
│   ├── 02-dependencies.sh
│   ├── 03-video-drivers.sh
│   ├── 04-autologin.sh
│   ├── 05-grub-splash.sh
│   ├── 06-plymouth.sh
│   ├── 07-openbox.sh
│   ├── 08-nfs.sh
│   ├── 09-retropie.sh
│   ├── 10-flycast.sh
│   └── 11-emulator-config.sh
│
├── configs/
│   ├── openbox/
│   │   └── autostart             ← Reference OpenBox autostart
│   ├── retroarch/
│   │   └── retroarch.cfg         ← RetroArch config reference
│   └── emulators/
│       └── flycast/
│           └── emu.cfg           ← Flycast/Dreamcast config
│
├── docs/
│   ├── INSTALL.md                ← Step-by-step install walkthrough
│   ├── SPLASH_THEMES.md          ← Plymouth theme reference
│   ├── NFS_SETUP.md              ← NFS server/client setup
│   └── TROUBLESHOOTING.md        ← Common issues and fixes
│
└── assets/
    └── plymouth-themes/          ← Git submodule: HerbFargus themes
```

---

## Post-Install Tips

**Check your IP address** (for SSH or NFS clients):
```bash
# From EmulationStation: RetroPie → Show IP Address
# Or from SSH:
ip addr show | grep 'inet ' | grep -v 127
```

**Update RetroPie packages:**
```bash
cd ~/RetroPie-Setup
sudo ./retropie_setup.sh
# → Update → Update all installed packages
```

**Re-run a single module** (e.g. after hardware change):
```bash
sudo ~/mediacade/scripts/03-video-drivers.sh
```

**Change display resolution:**
```bash
# Edit retropie.cfg, then re-run:
sudo ~/mediacade/scripts/02-dependencies.sh
sudo ~/mediacade/scripts/05-grub-splash.sh
sudo update-grub && sudo reboot
```

**SSH into RetroPie while EmulationStation is running:**
```bash
ssh pi@<retropie-ip>
# To restart ES after adding ROMs:
sudo /usr/local/bin/restart-es
```

---

## Troubleshooting

| Symptom | Quick fix |
|---|---|
| Boots to login prompt instead of ES | Check `/tmp/xorg-startup.log`; re-run `04-autologin.sh` |
| Black screen after GRUB | Re-run `03-video-drivers.sh`; check GPU was auto-detected correctly |
| No audio | `pactl list sinks`; verify user is in `audio` group |
| Controller not detected | Run `jstest /dev/input/js0`; reconfigure in ES (Start → Configure Input) |
| ROMs not showing in ES | Check file is in correct `roms/<s>/` directory with correct extension |
| NFS mount fails | Ping server IP; check `systemctl status nfs-common` |
| Splash not showing | `cat /proc/cmdline` — must contain `splash`; re-run `05-grub-splash.sh` and `06-plymouth.sh` |
| Flycast: game won't load | Verify BIOS files in `~/RetroPie/BIOS/dc/`; use CDI format for best compatibility |

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed diagnosis steps.

---

## Differences from MizterB/RetroPie-Setup-Ubuntu

| Area | MizterB original | mediacade |
|---|---|---|
| Ubuntu version | 18.04 / 20.04 | 24.04 LTS |
| GPU drivers | Basic Mesa | Intel/NVIDIA/AMD auto-detect + Vulkan stack |
| Boot silence | Partial | Full: GRUB hidden, `loglevel=3`, systemd silent, Plymouth seamless |
| Display | Basic | 1080p forced at GRUB framebuffer and Xorg; 4K-panel optimized |
| Splash screens | None | Full HerbFargus collection + interactive selector |
| NFS | None | Server + client + both modes; systemd automount |
| lr-flycast | None | Binary install + source fallback (Vulkan enabled) |
| Modular re-runs | Limited | Every script independently re-runnable |
| Config | Hardcoded values | Single `retropie.cfg` controls all modules |

---

## Documentation

- 📖 [Detailed Install Guide](docs/INSTALL.md)
- 🎨 [Splash Screen Themes](docs/SPLASH_THEMES.md)
- 📡 [NFS ROMs Sharing](docs/NFS_SETUP.md)
- 🔧 [Troubleshooting](docs/TROUBLESHOOTING.md)

---

## Credits & Acknowledgements

| Project | Role |
|---|---|
| [MizterB/RetroPie-Setup-Ubuntu](https://github.com/MizterB/RetroPie-Setup-Ubuntu) | Original inspiration and foundation |
| [RetroPie Project](https://retropie.org.uk/) | The core emulation platform |
| [HerbFargus/plymouth-themes](https://github.com/HerbFargus/plymouth-themes) | Plymouth splash screen themes |
| [Libretro/flycast](https://github.com/libretro/flycast) | Dreamcast/NAOMI/AtomisWave emulation |
| [OpenBox](http://openbox.org/) | Window manager |
| [Mesa / freedesktop.org](https://www.mesa3d.org/) | Open-source GPU drivers and Vulkan |

---

## License

[MIT](LICENSE) — use freely, attribution appreciated.

> This project does not distribute any copyrighted ROM files, BIOS images, or commercial software.  
> You are responsible for complying with the laws in your jurisdiction regarding game backups.
