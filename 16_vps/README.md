# 16_vps/ — ad-hoc VPS operational notes (reference-only, on-demand)

Not a numbered layer, not applied by `make all` or `CLAUDE_CONSUMER.md` —
same "reference-only, on-demand" treatment as `10_embedded-hw`. This is
operational knowledge about the owner's VPS (`vps1` — see
`../secrets/hosts.env`), not something a fresh-box rebuild needs by
default.

```
16_vps/
  cldOnVps.md              # note: resuming a Claude Code session as root on the VPS (tracked)
  rescueBkDumpMount.sh     # mounts a ZFS-snapshot VPS backup dump for manual recovery (tracked)
```

## `cldOnVps.md`

One-liner note for resuming a Claude Code session on the VPS when running
as root:

```bash
IS_SANDBOX=1 claude --dangerously-skip-permissions --resume <UUID> resume
```

**Read before using**: `--dangerously-skip-permissions` disables Claude
Code's normal per-action confirmation prompts. This was an accepted
trade-off for a specific root-on-VPS workflow on this host's own
infrastructure — re-decide consciously before reusing it elsewhere, same
spirit as the "no auth" flags called out in `08_ai-agent-tools/README.md`.

## `rescueBkDumpMount.sh`

Mounts a ZFS-based VPS backup snapshot (a `.zst`-compressed `zfs send`
stream containing a `os.qcow2` disk image) read-only at `/mnt/vps`, for
browsing/recovering files after a VPS-level incident:

1. Creates a scratch ZFS pool backed by a sparse file sized ~10% larger
   than the snapshot.
2. `zfs receive`s the snapshot into that pool (auto-detects `zstd`
   compression via the stream's magic bytes vs. a raw stream).
3. Connects the resulting `os.qcow2` via `qemu-nbd` and mounts its largest
   filesystem partition read-only at `/mnt/vps`.

Every step is idempotent (checks `zpool`/`zfs`/`mountpoint` state first and
skips what's already done), and it prints the exact teardown command
(`umount`/`qemu-nbd --disconnect`/`zpool destroy`) on exit via a `trap`.

**Needs root** (zpool/zfs/nbd operations) and these tools: `zfsutils-linux`
(`zpool`, `zfs`), `qemu-utils` (`qemu-nbd`), `xxd`, `coreutils` (`truncate`)
— the script checks for all of them up front and prints the exact
`apt-get install` line if any are missing.

## Apply

Nothing to "apply" ahead of time — these are run manually, only when
actually rescuing a VPS backup or resuming a root Claude session there, not
part of a fresh-box rebuild.

```bash
chmod +x 16_vps/rescueBkDumpMount.sh
```

## Machine-specific values

- `rescueBkDumpMount.sh`'s `SNAPSHOT="vps3414793-2026-05-31-12623.zst"` and
  `POOL="vps_tmp"` at the top of the script are **hardcoded to one specific
  past rescue** — edit both before reusing against a different snapshot
  file or if a `vps_tmp` pool name would collide with something else.

## Origin

Migrated in 2026-07-24 from `/data/proj/myGits/syso/gensys/vps/` (an
older, separate repo predating the `gensys` layered convention), carried
over verbatim.
