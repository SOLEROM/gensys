# 04_storage — `/data` mount (LUKS optional) + swap

**Required** — every later layer that stores anything under `/data`
(docker data-root, agent project dirs) assumes it is mounted, so this runs
before those. Whether `/data` is LUKS-encrypted is now a **per-station
choice** (`storage.data_encrypted` in `../00_configs/<name>.yaml`):

- `"yes"` — same-disk reinstall reusing an existing LUKS partition (this
  station, `myDevX1`), or a new station you encrypted at install time.
- `"no"` — a new station with a plain unencrypted `/data` partition; every
  cryptsetup/crypttab step below is skipped entirely.

## Purpose

- (If encrypted) unlock the `/data` LUKS volume via crypttab.
- Mount `/data` by filesystem UUID.
- Recreate swap — sized and (optionally) encrypted **on purpose**, not by
  silently replicating the old host's undersized/plaintext swapfile.

Bind mounts are deliberately **not** part of this layer anymore — see
"On-demand bind mounts" at the bottom.

---

## Prerequisites

```bash
sudo apt install -y cryptsetup    # only needed when storage.data_encrypted: "yes"
```

**Before running the Ubuntu 24.04 installer** (same-disk reinstall case):
choose manual/custom partitioning and **do not format the `/data`
partition** — only format `/` and `/boot/efi`. If it gets reformatted, this
whole layer is moot and `/data`'s contents are gone; that's the one step in
the entire reinstall that isn't recoverable by re-running a script.

---

## Files in this layer

None — this layer only edits `/etc/crypttab` (encrypted case) and
`/etc/fstab`, and creates a swap file. The per-station values (UUIDs,
sizes, encrypted yes/no) live in `../00_configs/<name>.yaml` under `storage:`.

---

## Apply

### 1. Unlock `/data` — only when `storage.data_encrypted: "yes"`

```bash
# confirm the LUKS partition is there and grab its UUID
sudo blkid | grep crypto_LUKS

# add to crypttab (passphrase unlock, no keyfile)
echo "crypto_data UUID=$LUKS_UUID none luks" | sudo tee -a /etc/crypttab

# unlock now (also happens automatically at boot via crypttab+fstab)
sudo cryptsetup luksOpen "/dev/disk/by-uuid/$LUKS_UUID" crypto_data
```

When `storage.data_encrypted: "no"`, skip this entire step — `apply.sh`
does, and never installs cryptsetup either.

> **Wrong-config guard**: `apply.sh` refuses to write a single crypttab/
> fstab line unless `/dev/disk/by-uuid/<UUID>` actually exists on this
> machine. This catches the "forgot to set `GENSYS_CONFIG`, silently fell
> back to another station's yaml" case before it plants boot-degrading
> lines in system files.

### 2. Mount `/data`

```bash
sudo mkdir -p /data
echo "UUID=$DATA_UUID /data ext4 defaults 0 2" | sudo tee -a /etc/fstab
sudo mount /data
```

### 3. Swap

Two parameters, asked once (`CLAUDE_CONSUMER.md`) or read from the station
config (`storage.swap_size` / `storage.swap_encrypted`):

- `SWAP_SIZE` (default `16G`) — the old host's live 10G swapfile was found
  **100% used** with ~300Mi RAM free — genuine thrashing. 16G (≈1× 16GB
  RAM) is a floor, not generous.
- `SWAP_ENCRYPTED` (default `yes`) — puts the swapfile inside `/data`
  instead of the plaintext root partition. **This only actually encrypts
  swap when `/data` itself is LUKS** (`data_encrypted: "yes"`); on a
  plaintext `/data`, `apply.sh` warns and you should either accept
  plaintext swap or use the dedicated-partition alternative below.

```bash
SWAP_SIZE="${SWAP_SIZE:-16G}"
SWAP_ENCRYPTED="${SWAP_ENCRYPTED:-yes}"

if [ "$SWAP_ENCRYPTED" = yes ]; then
  SWAP_PATH=/data/.swapfile   # inside the (LUKS) /data volume
else
  SWAP_PATH=/swapfile         # plaintext, root partition
fi

sudo fallocate -l "$SWAP_SIZE" "$SWAP_PATH"
sudo chmod 600 "$SWAP_PATH"
sudo mkswap "$SWAP_PATH"
sudo swapon "$SWAP_PATH"
echo "$SWAP_PATH none swap sw 0 0" | sudo tee -a /etc/fstab
```

**Dedicated encrypted swap partition (alternative)**: if you repartition to
carve out a separate swap partition, use a random-key crypttab entry —
contents are unreadable after every reboot, no passphrase needed:
```
# /etc/crypttab
cryptswap /dev/nvme0n1pN /dev/urandom swap,cipher=aes-xts-plain64,size=256
```
then `swap /dev/mapper/cryptswap none swap sw 0 0` in fstab. Not the
default — only worth it if you're repartitioning anyway.

`swappiness` (60) and `vfs_cache_pressure` (100) are stock Ubuntu defaults —
no tuning found worth carrying forward.

---

## On-demand bind mounts (NOT applied by this layer)

Per owner decision (2026-07-24) the two bind mounts the old lineage carried
are **not** scripted anywhere in this repo — they're a per-station, after-
install decision, applied by hand only on stations that want them:

```bash
# /proj as a short alias for /data/proj (most old-station tooling assumed it)
sudo mkdir -p /proj
echo '/data/proj /proj none bind 0 0' | sudo tee -a /etc/fstab
sudo mount /proj

# soil-wiki bind (only ever existed on the station running the soil pipeline)
sudo mkdir -p /data/proj/soil/git/wiki
echo '/proj/wikval/soilSync /data/proj/soil/git/wiki none bind 0 0' | sudo tee -a /etc/fstab
sudo mount /data/proj/soil/git/wiki
```

Consequence to keep in mind: config values elsewhere that reference
`/proj/...` paths (`services.soil_script`, `agents.dirs.resman`, the `pp`
alias's task-runner) only resolve on stations where you've applied the
`/proj` bind (or where you point those config values at `/data/proj/...`
directly instead).

---

## Verify

```bash
sudo cryptsetup status crypto_data   # active — only when data_encrypted: "yes"
mount | grep ' /data '               # mounted
swapon --show                        # SWAP_PATH, size matches $SWAP_SIZE
cat /proc/sys/vm/swappiness          # 60 (stock)
```

---

## Machine-specific values

All below live in `../00_configs/<name>.yaml` under `storage:` — edit there,
or override per-run with env vars (`LUKS_UUID=... make 04_storage`).

- **`storage.data_encrypted`** — `"yes"` (LUKS, this station) or `"no"`
  (plain partition, skips all cryptsetup/crypttab steps).
- **`storage.luks_uuid`** (→ `crypttab`) — only consumed when encrypted;
  this disk's actual `blkid`-derived value, re-derive on any other disk.
- **`storage.data_uuid`** (→ `fstab`, the `/data` filesystem UUID) — same
  caveat. `apply.sh` verifies both UUIDs exist on this machine before
  writing anything.
- **`storage.swap_size` / `storage.swap_encrypted`** — asked by
  `CLAUDE_CONSUMER.md` Step 2 if not already in the config; defaults
  `16G`/`yes`.
- **LUKS passphrase** — not stored anywhere in this repo, config included
  (by design — the one secret that must stay a human-memorized passphrase).
  Prompted interactively at first `luksOpen` and at every boot (no keyfile).

---

## Origin

Live values captured 2026-07-23 from the source host's `/etc/fstab`,
`/etc/crypttab`, `swapon --show`, and `free -h`. LUKS made optional and
bind mounts demoted to the on-demand section above on 2026-07-24 (owner
decision — new stations may use an unencrypted `/data`, and bind mounts
are handled per-station after install).
