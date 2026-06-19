# Network Settings Module — Integration Guide

## Prerequisites

- **NetworkManager** must be installed and running on the Raspberry Pi (`sudo apt install network-manager`)
- The user running 240-MP must have permission to run `nmcli` (this is the default for the primary user on Raspberry Pi OS)

## Installation

### 1. Copy module files into 240-MP

```bash
# Copy QML module (manifest + views + assets)
cp -r manifest.json assets views /path/to/240-mp/modules/network/

# Copy C++ backend source
cp -r src/NetworkBackend.h src/NetworkBackend.cpp /path/to/240-mp/src/modules/network/
```

### 2. Add to CMakeLists.txt

Add the backend source files to the `add_executable` call:

```cmake
src/modules/network/NetworkBackend.h
src/modules/network/NetworkBackend.cpp
```

### 3. Wire the backend in main.cpp

Add the include and registerModule call:

```cpp
#include "modules/network/NetworkBackend.h"

// After other backend constructors:
NetworkBackend networkBackend;

// After other registerModule calls:
appCore.registerModule("com.240mp.network", "networkBackend", &networkBackend, ctx);
```

### 4. Rebuild

```bash
cmake --build build
```

## How it works

The module uses `nmcli` (NetworkManager's CLI) to:

- **WiFi**: Scan for networks, connect with password, disconnect, forget saved networks
- **Ethernet**: Show status, switch between DHCP and static IP configuration

All `nmcli` calls are synchronous via `QProcess` — they block briefly but nmcli is fast enough that this doesn't cause noticeable UI lag.

## Views

| View | Purpose |
|---|---|
| `Items.qml` | Main menu — shows current connection status, links to WiFi and Ethernet config |
| `WifiList.qml` | Scanned WiFi networks — select to connect, [R] to rescan, [D] to forget |
| `WifiPassword.qml` | Password entry for secured WiFi networks — type password, [TAB] to show/hide, [ENTER] to connect |
| `EthernetConfig.qml` | Ethernet config — toggle DHCP/Static, edit IP/Gateway/DNS fields, Apply |
