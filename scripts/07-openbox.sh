#!/usr/bin/env bash
# =============================================================================
# 07-openbox.sh — OpenBox window manager configuration
#   • EmulationStation autostart
#   • Chromeless xterm for emulators
#   • Unclutter idle cursor hiding
#   • rc.xml (no window decorations for ES/emulators)
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"
RETROPIE_HOME="$(getent passwd "${RETROPIE_USER}" | cut -d: -f6)"

info()  { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

OB_CFG_DIR="${RETROPIE_HOME}/.config/openbox"
SCRIPT_CFG_DIR="$(dirname "$0")/../configs/openbox"

mkdir -p "$OB_CFG_DIR"

# ── autostart — what runs when OpenBox starts ─────────────────────────────────
info "Writing OpenBox autostart..."
cat > "${OB_CFG_DIR}/autostart" << EOF
#!/bin/sh
# mediacade OpenBox autostart
# This file is executed by openbox-session at startup.

# Disable screensaver / DPMS
xset s off
xset -dpms
xset s noblank

# Hide cursor (unclutter manages dynamic show/hide)
unclutter -idle ${UNCLUTTER_TIMEOUT:-3} -root -noevents &

# Force resolution (belt-and-suspenders — also set in .xinitrc)
$([ -n "${DISPLAY_OUTPUT:-}" ] \
    && echo "xrandr --output ${DISPLAY_OUTPUT} --mode ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} --rate ${DISPLAY_REFRESH} 2>/dev/null || true" \
    || echo "# (no DISPLAY_OUTPUT set — using auto)")

# Start EmulationStation
# emulationstation.sh handles restart loops; if ES exits, we kill X
emulationstation --no-splash
# If ES exits cleanly (e.g. Quit selected), shut down gracefully
openbox --exit
EOF
chmod +x "${OB_CFG_DIR}/autostart"

# ── rc.xml — OpenBox configuration ────────────────────────────────────────────
info "Writing OpenBox rc.xml..."
cat > "${OB_CFG_DIR}/rc.xml" << 'RCXML'
<?xml version="1.0" encoding="UTF-8"?>
<!-- mediacade OpenBox rc.xml -->
<openbox_config xmlns="http://openbox.org/3.4/rc">

  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>

  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <focusDelay>200</focusDelay>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>

  <placement>
    <policy>Smart</policy>
    <center>yes</center>
    <monitor>Primary</monitor>
    <primaryMonitor>1</primaryMonitor>
  </placement>

  <theme>
    <!-- Minimal decoration: no title bars for full-screen apps -->
    <name>Clearlooks</name>
    <titleLayout>NLC</titleLayout>
    <keepBorder>no</keepBorder>
    <animateIconify>no</animateIconify>
    <font place="ActiveWindow">
      <name>sans</name>
      <size>8</size>
      <weight>normal</weight>
      <slant>normal</slant>
    </font>
  </theme>

  <desktops>
    <number>1</number>
    <firstdesk>1</firstdesk>
    <names><name>RetroPie</name></names>
    <popupTime>0</popupTime>
  </desktops>

  <resize>
    <drawContents>yes</drawContents>
    <popupShow>NonPixel</popupShow>
  </resize>

  <mouse>
    <dragThreshold>1</dragThreshold>
    <doubleClickTime>200</doubleClickTime>
    <screenEdgeWarpTime>0</screenEdgeWarpTime>
    <screenEdgeWarpMouse>false</screenEdgeWarpMouse>
    <context name="Frame">
      <!-- Disable right-click menu on window frame -->
    </context>
    <context name="Desktop">
      <!-- No right-click desktop menu -->
    </context>
  </mouse>

  <keyboard>
    <!-- Alt+F4 kills focused window -->
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>
    <!-- Ctrl+Alt+T launches chromeless xterm -->
    <keybind key="C-A-t">
      <action name="Execute">
        <command>xterm -name retropie-term</command>
      </action>
    </keybind>
  </keyboard>

  <applications>

    <!-- EmulationStation: full-screen, no decoration -->
    <application name="emulationstation" class="EmulationStation">
      <fullscreen>yes</fullscreen>
      <decor>no</decor>
      <maximized>yes</maximized>
      <layer>above</layer>
      <focus>yes</focus>
    </application>

    <!-- Generic emulator windows (RetroArch etc.) -->
    <application class="retroarch" name="retroarch">
      <fullscreen>yes</fullscreen>
      <decor>no</decor>
      <maximized>yes</maximized>
    </application>

    <!-- Chromeless terminal for emulator launches -->
    <application name="retropie-term">
      <decor>no</decor>
      <border>no</border>
    </application>

  </applications>

</openbox_config>
RCXML

# ── menu.xml — minimal right-click menu (disabled for ES, available for debug) ─
info "Writing OpenBox menu.xml..."
cat > "${OB_CFG_DIR}/menu.xml" << 'MENUXML'
<?xml version="1.0" encoding="utf-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="RetroPie">
    <item label="EmulationStation">
      <action name="Execute"><command>emulationstation</command></action>
    </item>
    <separator/>
    <item label="Terminal">
      <action name="Execute"><command>xterm -name retropie-term</command></action>
    </item>
    <separator/>
    <item label="Reload OpenBox">
      <action name="Reconfigure"/>
    </item>
    <item label="Reboot">
      <action name="Execute"><command>sudo reboot</command></action>
    </item>
    <item label="Shutdown">
      <action name="Execute"><command>sudo poweroff</command></action>
    </item>
  </menu>
</openbox_menu>
MENUXML

# ── xterm config — chromeless: no scrollbar, menu, cursor ─────────────────────
info "Writing chromeless xterm config..."
cat > "${RETROPIE_HOME}/.Xresources" << 'XRES'
! mediacade — Chromeless xterm configuration

! Core appearance
XTerm*faceName:         Monospace
XTerm*faceSize:         11
XTerm*background:       black
XTerm*foreground:       white

! Hide chrome
XTerm*scrollBar:        false
XTerm*rightScrollBar:   false
XTerm*title:            ""
XTerm*iconName:         ""
XTerm*borderWidth:      0
XTerm*internalBorder:   0

! Hide cursor when idle (handled by unclutter, but belt+suspenders)
XTerm*pointerShape:     none
XTerm*pointerColor:     black
XTerm*pointerColorBackground: black

! Disable context menu (right/middle click)
XTerm*omitTranslation:  popup-menu

! Geometry: full screen (will be managed by OpenBox application rules)
XTerm*geometry:         80x24

! No bell
XTerm*bellIsUrgent:     false
XTerm*visualBell:       false
XRES
chown "${RETROPIE_USER}:${RETROPIE_USER}" "${RETROPIE_HOME}/.Xresources"

# Merge Xresources on X start
if ! grep -q "xrdb" "${RETROPIE_HOME}/.xinitrc" 2>/dev/null; then
    sed -i '1a xrdb -merge ~/.Xresources 2>/dev/null || true' \
        "${RETROPIE_HOME}/.xinitrc" 2>/dev/null || true
fi

# ── Set ownership ─────────────────────────────────────────────────────────────
chown -R "${RETROPIE_USER}:${RETROPIE_USER}" "${OB_CFG_DIR}"

info "OpenBox configuration complete ✓"
