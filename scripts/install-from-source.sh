#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# 240-MP install-from-source for Raspberry Pi OS Trixie (arm64)
#
# Clones (or updates) the repo, builds, installs to /opt/240mp, and optionally
# sets up autostart. Run again at any time to update to the latest commit.
#
# Usage:
#   bash install-from-source.sh                # install from main branch
#   bash install-from-source.sh some-branch    # install from a specific branch
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="https://github.com/SlopHobbyist/240-MP.git"
BRANCH="${1:-main}"
SRC_DIR="$HOME/240-MP"
INSTALL_DIR="/opt/240mp"
LAUNCHER="/usr/local/bin/240mp"
SYSTEMD_SERVICE="/etc/systemd/system/240mp.service"

# ── Verify architecture ──────────────────────────────────────────────────────
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "Error: this installer is for arm64 (aarch64). Detected: $ARCH"
    exit 1
fi

# ── Install build + runtime dependencies ─────────────────────────────────────
echo "Installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y \
    build-essential cmake git \
    qt6-base-dev qt6-declarative-dev \
    qml6-module-qtquick qml6-module-qtquick-controls \
    qml6-module-qtquick-window qml6-module-qtquick-effects \
    libqt6svg6 qt6-svg-dev qt6-svg-plugins qt6-wayland \
    libdrm-dev libxkbcommon-dev libssl-dev \
    libsdl2-dev \
    mpv \
    pipewire-audio \
    libspa-0.2-bluetooth \
    pulseaudio-utils

# ── udev rule: allow tty group to open /dev/tty0 for VT switching ────────────
echo 'KERNEL=="tty0", GROUP="tty", MODE="0620"' \
    | sudo tee /etc/udev/rules.d/99-240mp-tty.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger /dev/tty0

# ── polkit: let netdev group manage NetworkManager ───────────────────────────
install_polkit_rule() {
    local RULES_FILE="$SRC_DIR/scripts/50-240mp-networkmanager.rules"
    if [ -f "$RULES_FILE" ]; then
        sudo cp "$RULES_FILE" /etc/polkit-1/rules.d/50-240mp-networkmanager.rules
    fi
}

# ── Bluetooth audio: WirePlumber config for headless setups ──────────────────
sudo mkdir -p /etc/wireplumber/wireplumber.conf.d
sudo tee /etc/wireplumber/wireplumber.conf.d/disable-seat-monitoring.conf > /dev/null << 'WPCONF'
wireplumber.profiles = {
  main = {
    monitor.bluez.seat-monitoring = disabled
  }
}
WPCONF

# ── Clone or update ─────────────────────────────────────────────────────────
if [ -d "$SRC_DIR/.git" ]; then
    echo "Updating existing source in $SRC_DIR..."
    git -C "$SRC_DIR" fetch origin
    git -C "$SRC_DIR" checkout "$BRANCH"
    git -C "$SRC_DIR" reset --hard "origin/$BRANCH"
else
    echo "Cloning $REPO into $SRC_DIR..."
    git clone -b "$BRANCH" "$REPO" "$SRC_DIR"
fi

# ── polkit rule (needs repo to be cloned first) ─────────────────────────────
install_polkit_rule

# ── Build ────────────────────────────────────────────────────────────────────
echo "Building..."
cmake -B "$SRC_DIR/build" -S "$SRC_DIR"
cmake --build "$SRC_DIR/build" -j"$(nproc)"
echo "Build succeeded."

# ── Install to /opt/240mp ────────────────────────────────────────────────────
echo "Installing to $INSTALL_DIR..."
sudo mkdir -p "${INSTALL_DIR}/bin"
sudo mkdir -p "${INSTALL_DIR}/share/240mp"

sudo cp "$SRC_DIR/build/240mp" "${INSTALL_DIR}/bin/240mp"

SHARE="${INSTALL_DIR}/share/240mp"
sudo cp "$SRC_DIR/Main.qml" "${SHARE}/Main.qml"
sudo rsync -a --delete "$SRC_DIR/views/"    "${SHARE}/views/"
sudo rsync -a --delete "$SRC_DIR/assets/"   "${SHARE}/assets/"
sudo rsync -a --delete "$SRC_DIR/modules/"  "${SHARE}/modules/"
sudo rsync -a --delete "$SRC_DIR/scripts/"  "${SHARE}/scripts/"

# ── Create launcher ─────────────────────────────────────────────────────────
echo "Creating launcher at ${LAUNCHER}..."
sudo tee "${LAUNCHER}" > /dev/null << 'LAUNCHER_SCRIPT'
#!/usr/bin/env bash
# 240-MP launcher — auto-detects display platform
INSTALL_DIR="/opt/240mp"

if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
elif [ -n "${DISPLAY:-}" ]; then
    QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
else
    QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-eglfs}"
    export QT_QPA_EGLFS_ALWAYS_SET_MODE=1
    export QT_QPA_EGLFS_KMS_ATOMIC=1

    KMS_CARD=""
    for s in /sys/class/drm/card*-*/status; do
        [ -e "$s" ] || continue
        if [ "$(cat "$s")" = "connected" ]; then
            n=$(basename "$(dirname "$s")"); KMS_CARD="${n%%-*}"; break
        fi
    done
    if [ -z "$KMS_CARD" ]; then
        for d in /sys/class/drm/card*-*; do
            [ -e "$d" ] || continue
            n=$(basename "$d"); KMS_CARD="${n%%-*}"; break
        done
    fi
    if [ -n "$KMS_CARD" ] && [ -e "/dev/dri/$KMS_CARD" ]; then
        KMS_DIR="${XDG_RUNTIME_DIR:-/tmp}"
        [ -d "$KMS_DIR" ] || KMS_DIR="/tmp"
        KMS_CONF="${KMS_DIR}/240mp-kms.json"
        printf '{ "device": "/dev/dri/%s" }\n' "$KMS_CARD" > "$KMS_CONF"
        export QT_QPA_EGLFS_KMS_CONFIG="$KMS_CONF"
    fi
fi

export QT_QPA_PLATFORM
export QML2_IMPORT_PATH="/usr/lib/aarch64-linux-gnu/qt6/qml"

exec "${INSTALL_DIR}/bin/240mp" "$@"
LAUNCHER_SCRIPT

sudo chmod +x "${LAUNCHER}"

# ── Optional: systemd autostart ──────────────────────────────────────────────
echo ""
read -r -p "Install systemd autostart service? [y/N] " REPLY
if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
    read -r -p "Run service as user [default: pi]: " SERVICE_USER
    SERVICE_USER="${SERVICE_USER:-pi}"

    SERVICE_UID=$(id -u "${SERVICE_USER}" 2>/dev/null || echo 1000)

    if ! sudo loginctl enable-linger "${SERVICE_USER}"; then
        echo "WARNING: loginctl enable-linger failed. 240-MP may not start at boot."
        echo "Run manually after reboot: sudo loginctl enable-linger ${SERVICE_USER}"
    fi

    sudo tee "${SYSTEMD_SERVICE}" > /dev/null << UNIT
[Unit]
Description=240-MP Media Player
After=multi-user.target sound.target user-runtime-dir@${SERVICE_UID}.service
Wants=user-runtime-dir@${SERVICE_UID}.service

[Service]
Type=simple
User=${SERVICE_USER}
SupplementaryGroups=tty video input
AmbientCapabilities=CAP_SYS_TTY_CONFIG
Environment=QT_QPA_PLATFORM=eglfs
Environment=QT_QPA_EGLFS_ALWAYS_SET_MODE=1
Environment=QT_QPA_EGLFS_KMS_ATOMIC=1
Environment=QML2_IMPORT_PATH=/usr/lib/aarch64-linux-gnu/qt6/qml
Environment=XDG_RUNTIME_DIR=/run/user/${SERVICE_UID}
Environment=MP240_AUTOSTART=1
ExecStartPre=+-/usr/bin/systemctl stop 240mp-terminal.service
ExecStart=${LAUNCHER}
Restart=on-failure
RestartSec=5s
RestartPreventExitStatus=10
ExecStopPost=+/usr/local/bin/240mp-stop
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

    sudo tee /usr/local/bin/240mp-stop > /dev/null << 'STOP_HELPER'
#!/usr/bin/env bash
if [ "${EXIT_STATUS:-}" = "10" ]; then
    systemctl start 240mp-terminal.service
else
    systemctl poweroff
fi
STOP_HELPER
    sudo chmod +x /usr/local/bin/240mp-stop

    sudo tee /etc/systemd/system/240mp-terminal.service > /dev/null << 'TERMINAL_UNIT'
[Unit]
Description=240-MP exit-to-terminal login shell

[Service]
Type=idle
ExecStartPre=-/usr/bin/chvt 1
ExecStart=-/sbin/agetty tty1 linux
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
KillMode=process
Restart=no
TERMINAL_UNIT

    sudo systemctl mask getty@tty1.service autovt@.service
    sudo systemctl daemon-reload
    sudo systemctl enable 240mp.service
    echo "Service installed and enabled."
    echo "Start now with: sudo systemctl start 240mp"
fi

echo ""
echo "240-MP installed successfully from source."
echo "Source directory: $SRC_DIR"
echo "Run: 240mp"
echo "To update later, run this script again."
