#!/usr/bin/env bash
# =============================================================================
# 11-emulator-config.sh — Pre-built emulator configuration
#   • RetroArch base config (hotkeys, video, audio, shaders)
#   • EmulationStation settings
#   • Per-system configurations
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"
RETROPIE_HOME="$(getent passwd "${RETROPIE_USER}" | cut -d: -f6)"

info()    { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

CONFIGS_SRC="$(dirname "$0")/../configs"
RA_CFG_DIR="/opt/retropie/configs/all"
RA_CFG="${RA_CFG_DIR}/retroarch.cfg"
ES_CFG_DIR="${RETROPIE_HOME}/.emulationstation"

mkdir -p "$RA_CFG_DIR" "$ES_CFG_DIR"

# ── RetroArch base config ─────────────────────────────────────────────────────
info "Writing RetroArch base configuration..."
cat > "$RA_CFG" << EOF
# =============================================================================
# retroarch.cfg — mediacade base RetroArch config
# =============================================================================

# ── Video ─────────────────────────────────────────────────────────────────────
video_driver = "gl"
video_fullscreen = true
video_windowed_fullscreen = false
video_fullscreen_x = ${DISPLAY_WIDTH}
video_fullscreen_y = ${DISPLAY_HEIGHT}
video_refresh_rate = ${DISPLAY_REFRESH}.000000
video_vsync = true
video_hard_sync = false
video_hard_sync_frames = 0
video_frame_delay = 0
video_black_frame_insertion = false
video_threaded = false
video_smooth = false
video_scale_integer = false
video_aspect_ratio_auto = true
video_aspect_ratio = -1.000000
video_filter_dir = "/opt/retropie/configs/all/retroarch/filters/video/"
video_font_enable = false

# ── Shaders ───────────────────────────────────────────────────────────────────
video_shader_enable = false
video_shader_dir = "/opt/retropie/configs/all/retroarch/shaders/"

# ── Audio ─────────────────────────────────────────────────────────────────────
audio_enable = true
audio_driver = "pulse"
audio_out_rate = 48000
audio_latency = 64
audio_sync = true
audio_volume = 0.000000
audio_mute_enable = false
audio_dsp_plugin_dir = "/opt/retropie/configs/all/retroarch/filters/audio/"

# ── Input ─────────────────────────────────────────────────────────────────────
input_driver = "udev"
input_joypad_driver = "udev"
input_autoconfig_dir = "/opt/retropie/configs/all/retroarch/autoconfig/"
input_remapping_directory = "/opt/retropie/configs/all/retroarch/remaps/"

# ── Hotkeys (all map to Select/Special button combinations) ──────────────────
input_enable_hotkey_btn = "8"          # Select button (commonly btn 8)
input_exit_emulator_btn = "9"          # Start (Select+Start = exit)
input_save_state_btn = "5"             # L1 (Select+L1 = save state)
input_load_state_btn = "4"             # L2 (Select+L2 = load state)
input_state_slot_increase_btn = "11"   # R1 (Select+R1 = next slot)
input_state_slot_decrease_btn = "10"   # R2 (Select+R2 = prev slot)
input_reset_btn = "0"                  # A/Cross (Select+A = reset)
input_menu_toggle_btn = "1"            # B/Circle (Select+B = RA menu)
input_screenshot_btn = "2"             # X/Square (Select+X = screenshot)
input_pause_toggle_btn = "3"           # Y/Triangle (Select+Y = pause)
input_fast_forward_hold_btn = "7"      # R1 hold (Select+R1 hold = fast fwd)

# Keyboard escape also exits (for debug/maintenance)
input_exit_emulator = escape

# ── RetroArch menu ────────────────────────────────────────────────────────────
menu_driver = "ozone"
menu_unified_controls = false
menu_show_advanced_settings = true
menu_dynamic_wallpaper_enable = false
game_history_list_enable = true
# Don't show detailed game info by default
quick_menu_show_information = true

# ── Paths ─────────────────────────────────────────────────────────────────────
libretro_directory = "/opt/retropie/libretrocores/"
libretro_info_path = "/opt/retropie/configs/all/retroarch/cores/"
rgui_config_directory = "/opt/retropie/configs/all/retroarch/"
savefile_directory = "/home/${RETROPIE_USER}/RetroPie/saves"
savestate_directory = "/home/${RETROPIE_USER}/RetroPie/saves"
screenshot_directory = "/home/${RETROPIE_USER}/RetroPie/screenshots"
system_directory = "/home/${RETROPIE_USER}/RetroPie/BIOS"
assets_directory = "/opt/retropie/configs/all/retroarch/assets/"
content_database_path = "/opt/retropie/configs/all/retroarch/database/rdb/"
cursor_directory = "/opt/retropie/configs/all/retroarch/database/cursors/"
cheat_database_path = "/opt/retropie/configs/all/retroarch/cheats/"
overlay_directory = "/opt/retropie/configs/all/retroarch/overlays/"
resampler_quality = 3

# ── Misc ──────────────────────────────────────────────────────────────────────
config_save_on_exit = false
fps_show = false
memory_show = false
statistics_show = false
perfcnt_enable = false
log_verbosity = false
stdin_cmd_enable = false
EOF

# Create save/screenshot directories
for d in \
    "${RETROPIE_HOME}/RetroPie/saves" \
    "${RETROPIE_HOME}/RetroPie/screenshots"; do
    mkdir -p "$d"
done

# ── EmulationStation settings ─────────────────────────────────────────────────
info "Writing EmulationStation settings..."
cat > "${ES_CFG_DIR}/es_settings.cfg" << EOF
<?xml version="1.0"?>
<bool name="CaptionsCompatibility" value="true" />
<bool name="DrawFramerate" value="false" />
<bool name="EnableSounds" value="true" />
<bool name="ExitOnEscapeSystemCount" value="false" />
<bool name="FavoritesFirst" value="false" />
<bool name="FavoritesOnly" value="false" />
<bool name="FollowSymlinks" value="false" />
<bool name="ForceKid" value="false" />
<bool name="ForceKiosk" value="false" />
<bool name="HideEmpty" value="false" />
<bool name="IgnoreGamelist" value="false" />
<bool name="MoveCarousel" value="true" />
<bool name="ParseGamelistOnly" value="false" />
<bool name="QuickSystemSelect" value="true" />
<bool name="SaveGamelistsMode" value="true" />
<bool name="ShowHiddenFiles" value="false" />
<bool name="SlideshowScreensaverGameName" value="true" />
<bool name="SlideshowScreensaverMarquee" value="true" />
<bool name="SlideshowScreensaverRandom" value="true" />
<bool name="SlideshowScreensaverVideoMode" value="false" />
<bool name="SortAllSystemsWithFavorites" value="false" />
<bool name="StretchVideoOnScreenSaver" value="false" />
<bool name="VideoAudio" value="true" />
<string name="AudioDevice" value="default" />
<string name="BackgroundMusicSource" value="random" />
<string name="CollectionSystemsAuto" value="" />
<string name="CollectionSystemsCustom" value="" />
<string name="ScreenSaverBehavior" value="dim" />
<string name="ScreenSaverGameInfo" value="never" />
<string name="ScreenSaverTime" value="5" />
<string name="StartupSystem" value="" />
<string name="ThemeSet" value="carbon" />
<string name="UIMode" value="Full" />
EOF

# ── Per-system overrides ──────────────────────────────────────────────────────
info "Writing per-system RetroArch overrides..."

# N64 — needs more GPU headroom
mkdir -p "/opt/retropie/configs/n64"
cat > "/opt/retropie/configs/n64/retroarch.cfg" << 'EOF'
video_driver = "gl"
video_smooth = true
# Parallel-N64 / mupen64plus internal resolution
video_fullscreen = true
EOF

# SNES — pixel-perfect integer scale
mkdir -p "/opt/retropie/configs/snes"
cat > "/opt/retropie/configs/snes/retroarch.cfg" << 'EOF'
video_scale_integer = true
video_smooth = false
video_aspect_ratio = 1.333
EOF

# NES — same as SNES
mkdir -p "/opt/retropie/configs/nes"
cat > "/opt/retropie/configs/nes/retroarch.cfg" << 'EOF'
video_scale_integer = true
video_smooth = false
video_aspect_ratio = 1.333
EOF

# PSP — native high-res rendering
mkdir -p "/opt/retropie/configs/psp"
cat > "/opt/retropie/configs/psp/retroarch.cfg" << 'EOF'
video_smooth = false
EOF

# ── Install emulation-related scripts ─────────────────────────────────────────
info "Installing RetroPie helper scripts..."
SCRIPTS_DEST="/opt/retropie/scripts"
mkdir -p "$SCRIPTS_DEST"

# Basic restart EmulationStation wrapper
cat > "/usr/local/bin/restart-es" << 'ESRESTART'
#!/usr/bin/env bash
# Safely restart EmulationStation
pkill -TERM emulationstation 2>/dev/null || true
sleep 2
pkill -9 emulationstation 2>/dev/null || true
sudo -u "${RETROPIE_USER:-pi}" DISPLAY=:0 emulationstation &
ESRESTART
chmod +x /usr/local/bin/restart-es

# ── Fix permissions ───────────────────────────────────────────────────────────
info "Setting final permissions..."
chown -R "${RETROPIE_USER}:${RETROPIE_USER}" \
    "$ES_CFG_DIR" \
    "${RETROPIE_HOME}/RetroPie" \
    2>/dev/null || true

chown -R root:root /opt/retropie/configs 2>/dev/null || true
chmod -R 755 /opt/retropie/configs 2>/dev/null || true
# Allow user to write their own save/config files
chown -R "${RETROPIE_USER}:${RETROPIE_USER}" \
    "/opt/retropie/configs/all" 2>/dev/null || true

# ── Apply pre-bundled configs if present ─────────────────────────────────────
if [[ -d "${CONFIGS_SRC}/retroarch" ]]; then
    info "Applying pre-bundled RetroArch configs..."
    cp -rn "${CONFIGS_SRC}/retroarch/." "/opt/retropie/configs/all/retroarch/" 2>/dev/null || true
fi

if [[ -d "${CONFIGS_SRC}/emulators/flycast" ]]; then
    info "Applying pre-bundled Flycast configs..."
    mkdir -p "/opt/retropie/configs/dreamcast"
    cp -rn "${CONFIGS_SRC}/emulators/flycast/." "/opt/retropie/configs/dreamcast/" 2>/dev/null || true
fi

success "Emulator configuration complete ✓"
info "RetroArch hotkeys:"
info "  Select + Start     → Exit emulator"
info "  Select + B         → RetroArch menu"
info "  Select + L1        → Save state"
info "  Select + L2        → Load state"
info "  Select + R1 (hold) → Fast forward"
