#!/usr/bin/env bash
# 04_storage/apply.sh — mirrors this layer's README.md Apply section.
# Idempotent: safe to re-run (checks before appending fstab/crypttab lines).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"

DATA_ENCRYPTED="${DATA_ENCRYPTED:-$(cfg storage.data_encrypted yes)}"
LUKS_UUID="${LUKS_UUID:-$(cfg storage.luks_uuid)}"
DATA_UUID="${DATA_UUID:-$(cfg storage.data_uuid)}"
SWAP_SIZE="${SWAP_SIZE:-$(cfg storage.swap_size 16G)}"
SWAP_ENCRYPTED="${SWAP_ENCRYPTED:-$(cfg storage.swap_encrypted yes)}"

# A wrong-station config or a typo here silently changes what gets encrypted
# — refuse anything but a literal yes/no.
for v in DATA_ENCRYPTED SWAP_ENCRYPTED; do
  case "${!v}" in
    yes|no) ;;
    *) echo "ERROR: $v must be yes|no, got '${!v}' — fix the storage: block in ${CONFIG_FILE:-the station config}." >&2
       exit 1 ;;
  esac
done

if [ "$DATA_ENCRYPTED" = yes ]; then
  echo "==> LUKS /data (storage.data_encrypted=yes)"
  command -v cryptsetup >/dev/null || sudo apt-get install -y cryptsetup

  # Refuse to touch crypttab with a UUID that isn't on THIS box — catches
  # "forgot GENSYS_CONFIG, silently fell back to another station's yaml"
  # BEFORE it plants boot-degrading lines in system files.
  if [ ! -b "/dev/disk/by-uuid/$LUKS_UUID" ]; then
    echo "ERROR: no block device with UUID '$LUKS_UUID' on this machine." >&2
    echo "storage.luks_uuid in the active config ($CONFIG_FILE) does not" >&2
    echo "match this disk — wrong GENSYS_CONFIG? Re-derive with blkid." >&2
    exit 1
  fi

  echo "==> /etc/crypttab (crypto_data)"
  grep -qE "^crypto_data[[:space:]]" /etc/crypttab 2>/dev/null || \
    echo "crypto_data UUID=$LUKS_UUID none luks" | sudo tee -a /etc/crypttab

  if ! sudo cryptsetup status crypto_data >/dev/null 2>&1; then
    sudo cryptsetup luksOpen "/dev/disk/by-uuid/$LUKS_UUID" crypto_data
  fi
else
  echo "==> plain (unencrypted) /data — skipping cryptsetup/crypttab (storage.data_encrypted=no)"
fi

echo "==> /data mount"
# Same wrong-config guard for the filesystem UUID. (With LUKS, the fs UUID
# only becomes visible after luksOpen — that's why this runs after it.)
if [ ! -b "/dev/disk/by-uuid/$DATA_UUID" ]; then
  echo "ERROR: no filesystem with UUID '$DATA_UUID' on this machine." >&2
  echo "storage.data_uuid in the active config ($CONFIG_FILE) does not" >&2
  echo "match this disk — wrong GENSYS_CONFIG? Re-derive with blkid." >&2
  exit 1
fi
sudo mkdir -p /data
grep -qE "^UUID=${DATA_UUID}[[:space:]]" /etc/fstab || \
  echo "UUID=$DATA_UUID /data ext4 defaults 0 2" | sudo tee -a /etc/fstab
mountpoint -q /data || sudo mount /data

# No bind mounts here (the former /data/proj→/proj and soil-wiki binds) —
# per owner decision they're a per-station, on-demand step done AFTER the
# install; the recipe lives in README.md's "On-demand bind mounts" section.

echo "==> swap ($SWAP_SIZE, encrypted=$SWAP_ENCRYPTED)"
if [ "$SWAP_ENCRYPTED" = yes ]; then
  SWAP_PATH=/data/.swapfile
  if [ "$DATA_ENCRYPTED" != yes ]; then
    echo "WARNING: swap_encrypted=yes but data_encrypted=no — the swapfile" >&2
    echo "lands on a PLAINTEXT /data partition, so it is not actually" >&2
    echo "encrypted. Set storage.data_encrypted=yes or accept plaintext swap." >&2
  fi
else
  SWAP_PATH=/swapfile
fi

if ! swapon --show=NAME --noheadings | grep -qx "$SWAP_PATH"; then
  [ -f "$SWAP_PATH" ] || sudo fallocate -l "$SWAP_SIZE" "$SWAP_PATH"
  sudo chmod 600 "$SWAP_PATH"
  sudo mkswap "$SWAP_PATH"
  sudo swapon "$SWAP_PATH"
fi
# Persist regardless of whether swap was already active this boot — an
# interrupted earlier run (or a manual swapon) must still end up in fstab.
grep -qE "^${SWAP_PATH}[[:space:]]" /etc/fstab || \
  echo "$SWAP_PATH none swap sw 0 0" | sudo tee -a /etc/fstab

echo "==> verify"
if [ "$DATA_ENCRYPTED" = yes ]; then
  sudo cryptsetup status crypto_data | head -1
fi
mount | grep ' /data '
swapon --show
