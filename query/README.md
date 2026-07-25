# query

Read-only snapshot tools for auditing what is installed on a dev station.

## mapCurrentHost.sh

Freezes a full map of everything installed on the current host:

```sh
./mapCurrentHost.sh
```

Creates `./snapshots/<hostname>_<YYYY-MM-DD>/` next to the script, with one
file per install source:

| File | Source |
|------|--------|
| `00-summary.txt` | run log: OK / SKIP / WARN / FAIL per source |
| `01-host-info.txt` | hostname, kernel, os-release |
| `10-15` | apt/dpkg, apt-manual, snap, flatpak, brew, nix |
| `20-31` | pip, pipx, uv, conda, npm, pnpm, yarn, cargo, rustup, gem, go |
| `40-42` | docker images/containers, enabled systemd services |
| `50-51` | vscode + gnome-shell extensions |
| `60-62` | local bin dirs, AppImages in `$HOME`, every entry in each `$PATH` dir (plain `ls` — includes the odd non-executable) |
| `99-errors.log` | stderr of any command that misbehaved |

Package managers not present on the host are skipped and listed in the
summary. Re-running on the same day refreshes the same folder, so diffing
two dated folders shows what changed on the station between snapshots.

## snapshots/ is git-ignored

Only `mapCurrentHost.sh` and this README are tracked. The dated snapshot
folders under `snapshots/` are per-host audit data — regenerable on any
host by re-running the script, and they'd accumulate one folder per host
per audit if committed. Layer Origin sections may cite a snapshot by name
(e.g. `query/snapshots/edge_2026-07-24`); that's a pointer to local data,
re-derive by re-running the script if the folder is gone.
