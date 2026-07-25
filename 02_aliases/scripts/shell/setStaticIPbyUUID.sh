#!/bin/bash
set -e

# ──────────────── Usage ────────────────
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <connection_uuid> <static_ip/CIDR>"
    echo "Example: $0 <uuid-from-'nmcli con show'> 192.168.1.10/24"
    exit 1
fi

UUID="$1"
TARGET_IP="$2"

# ──────────────── Check UUID ────────────────
if ! nmcli -g uuid con show | grep -Fxq "$UUID"; then
    echo "❌ Error: No connection with UUID $UUID"
    exit 2
fi

# ──────────────── Get DEVICE via UUID only ────────────────
DEVICE=$(nmcli -t -f UUID,DEVICE con show | grep "^$UUID:" | cut -d: -f2)

if [[ -z "$DEVICE" ]]; then
    echo "❌ Error: No device currently bound to UUID: $UUID"
    exit 3
fi

if ! ip link show "$DEVICE" &>/dev/null; then
    echo "❌ Error: Device $DEVICE from UUID $UUID not found on system"
    exit 4
fi

# ──────────────── Get current settings ────────────────
CURRENT_IP=$(nmcli -g ipv4.addresses con show "$UUID" | head -n1)
CURRENT_METHOD=$(nmcli -g ipv4.method con show "$UUID")

if [[ "$CURRENT_IP" == "$TARGET_IP" && "$CURRENT_METHOD" == "manual" ]]; then
    echo "✅ Static IP $TARGET_IP already set on $DEVICE (UUID: $UUID)"
else
    echo "🔧 Applying static IP $TARGET_IP to $DEVICE (UUID: $UUID)..."
    nmcli con modify "$UUID" ipv4.addresses "$TARGET_IP"
    nmcli con modify "$UUID" ipv4.method manual
    nmcli con up "$UUID"
    echo "✅ Static IP applied."
fi

