#!/usr/bin/env bash
# Build 240-MP, stop the running instance, deploy to /opt/240mp, restart.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="/opt/240mp"

cd "$REPO_ROOT"

# ── Build ─────────────────────────────────────────────────────────────────────
echo "Building..."
if [ ! -f build/Makefile ]; then
    cmake -B build
fi
cmake --build build -j"$(nproc)"
echo "Build succeeded."

# ── Stop ──────────────────────────────────────────────────────────────────────
STOP_HELPER="/usr/local/bin/240mp-stop"
if [ -x "$STOP_HELPER" ]; then
    sudo chmod -x "$STOP_HELPER"
    REARM_STOP=1
else
    REARM_STOP=0
fi

echo "Stopping 240mp..."
if systemctl is-active --quiet 240mp 2>/dev/null; then
    sudo systemctl stop 240mp
    RESTART_SERVICE=1
else
    pkill -f "${INSTALL_DIR}/bin/240mp" 2>/dev/null || true
    RESTART_SERVICE=0
fi

# ── Deploy ────────────────────────────────────────────────────────────────────
echo "Deploying to ${INSTALL_DIR}..."

sudo cp build/240mp "${INSTALL_DIR}/bin/240mp"

SHARE="${INSTALL_DIR}/share/240mp"
sudo cp Main.qml "${SHARE}/Main.qml"
sudo rsync -a --delete views/    "${SHARE}/views/"
sudo rsync -a --delete assets/   "${SHARE}/assets/"
sudo rsync -a --delete modules/  "${SHARE}/modules/"
sudo rsync -a --delete scripts/  "${SHARE}/scripts/"

# ── Start ─────────────────────────────────────────────────────────────────────
if [ "$RESTART_SERVICE" -eq 1 ]; then
    echo "Starting 240mp service..."
    sudo systemctl start 240mp
else
    echo "Service was not running — skipping restart."
    echo "Start manually with: sudo systemctl start 240mp"
fi

# Re-arm the poweroff helper now that the new version is running.
if [ "${REARM_STOP:-0}" -eq 1 ]; then
    sudo chmod +x "$STOP_HELPER"
fi

echo "Done."
