#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="vps3414793-2026-05-31-12623.zst"
POOL="vps_tmp"
DATASET="$POOL/restore"
POOLIMG="$(pwd)/${POOL}.img"
NBD_DEV="/dev/nbd0"
VPS_MOUNT="/mnt/vps"

# ── check dependencies ───────────────────────────────────────────────────────
missing=()
for cmd in zpool zfs xxd truncate qemu-nbd zstd; do
  command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing commands: ${missing[*]}"
  pkgs=()
  for cmd in "${missing[@]}"; do
    case "$cmd" in
      zpool|zfs) pkgs+=("zfsutils-linux") ;;
      xxd)       pkgs+=("xxd") ;;
      truncate)  pkgs+=("coreutils") ;;
      qemu-nbd)  pkgs+=("qemu-utils") ;;
      zstd)      pkgs+=("zstd") ;;
    esac
  done
  mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | sort -u)
  echo "Install with:"
  echo "  sudo apt-get install -y ${pkgs[*]}"
  exit 1
fi

# ── cleanup hint on exit ─────────────────────────────────────────────────────
cleanup() {
  echo ""
  echo "Run to unmount and destroy everything:"
  echo "  umount $VPS_MOUNT; qemu-nbd --disconnect $NBD_DEV; zfs umount $DATASET; zpool destroy $POOL; rm -f \"$POOLIMG\""
}
trap cleanup EXIT

# ── step 1: ZFS pool ─────────────────────────────────────────────────────────
if zpool list "$POOL" &>/dev/null; then
  echo "[1/4] ZFS pool '$POOL' already exists, skipping."
else
  file_bytes=$(stat -c%s "$SNAPSHOT")
  pool_bytes=$(( file_bytes * 11 / 10 ))
  echo "[1/4] Creating temporary ZFS pool ($POOLIMG, $(( pool_bytes / 1024 / 1024 / 1024 )) GB sparse)..."
  truncate -s "$pool_bytes" "$POOLIMG"
  zpool create -O compression=lz4 "$POOL" "$POOLIMG"
fi

# ── step 2: receive snapshot ─────────────────────────────────────────────────
if zfs list "$DATASET" &>/dev/null; then
  echo "[2/4] Dataset '$DATASET' already received, skipping."
else
  echo "[2/4] Receiving ZFS snapshot (this may take a while)..."
  # 4 bytes = 8 hex chars — reading only 4 chars made the zstd branch unreachable
  read -rn8 magic < <(xxd -p -l4 "$SNAPSHOT")
  if [[ "$magic" == "fd2fb528" ]]; then
    zstd -d "$SNAPSHOT" --stdout | zfs receive -F "$DATASET"
  else
    zfs receive -F "$DATASET" < "$SNAPSHOT"
  fi
fi

# ── step 3: mount ZFS dataset ────────────────────────────────────────────────
if mountpoint -q "$(zfs get -H -o value mountpoint "$DATASET" 2>/dev/null)"; then
  echo "[3/4] ZFS dataset already mounted, skipping."
else
  echo "[3/4] Mounting ZFS dataset..."
  zfs mount "$DATASET" 2>/dev/null || true
fi
ZFS_MOUNT="$(zfs get -H -o value mountpoint "$DATASET")"
QCOW2="$ZFS_MOUNT/os.qcow2"

# ── step 4: mount QCOW2 via NBD ──────────────────────────────────────────────
if mountpoint -q "$VPS_MOUNT"; then
  echo "[4/4] QCOW2 already mounted at $VPS_MOUNT, skipping."
else
  echo "[4/4] Mounting QCOW2 image..."
  modprobe nbd max_part=8
  if ! lsblk "$NBD_DEV" 2>/dev/null | grep -q "nbd0p"; then
    qemu-nbd --read-only --connect="$NBD_DEV" "$QCOW2"
  fi
  partprobe "$NBD_DEV" 2>/dev/null || true
  sleep 1
  echo "Partitions on $NBD_DEV:"
  lsblk -o NAME,SIZE,FSTYPE,LABEL "$NBD_DEV"
  # pick the largest partition that has a filesystem
  part=$(lsblk -rbno NAME,SIZE,FSTYPE "$NBD_DEV" | awk '$3!="" && $1!="nbd0"{print $2, "/dev/"$1}' | sort -rn | awk 'NR==1{print $2}')
  if [[ -z "$part" ]]; then
    echo "Could not detect partition — check lsblk output above and mount manually:"
    echo "  mount -o ro /dev/nbd0pN $VPS_MOUNT"
    exit 1
  fi
  echo "Mounting $part..."
  mkdir -p "$VPS_MOUNT"
  mount -o ro "$part" "$VPS_MOUNT"
fi

echo ""
echo "Files available at: $VPS_MOUNT"
ls "$VPS_MOUNT"
