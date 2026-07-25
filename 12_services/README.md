# 12_services — network services, cron, sync/backup, mdplanner cross-ref, printer

## Purpose

The recurring background jobs and services that aren't covered by
`08_ai-agent-tools`:

- **Network-service packages** (absorbed from the former `15-toolset` layer
  on 2026-07-24): `openssh-server`, `nfs-kernel-server`, `dnsmasq`,
  `hostapd`, `openvpn`, `sssd` — installed and put into the same
  enabled/masked unit states as the source station.
- The soil-monitoring cron pipeline.
- Sync/backup tools — including pre-configuring this station's **Syncthing
  folders** from the station config (`syncthing.folders`) — and a note on
  the one CUPS printer.

---

## Prerequisites

`01_base` applied (apt baseline). `04_storage` applied first (the soil
script's paths are all under `/proj`). `secrets/cameras/soil.env` must
exist before enabling the cron line — the script now sources it instead of
inlining camera credentials (see `../secrets/README.md`). The soil
prerequisites only apply on a station whose config opts into the soil cron
(see Machine-specific values) — currently just `myDevX1`.

---

## Files in this layer

None — this layer ships no payload files. The soil cron line is composed by
`apply.sh` from the station config's `services:` values and merged into the
owning user's crontab (append, not overwrite — see Apply), and only on a
station that opts in. Keeping the line out of the repo means an opted-out
station's checkout carries no trace of the workload.

The script itself (`/proj/soil/soliAnal1.sh`) already lives on `/data`/`/proj`
and survives the reinstall via `04_storage` — only the **crontab line** is
on the wiped root fs and needs recreating. It was updated in-place (this
same session) to `source /data/proj/agents/gensys/secrets/cameras/soil.env`
instead of inlining `TAPO_USER`/`TAPO_PASS`.

---

## Apply

```bash
# 0. network-service packages + unit states matching the source station
#    (edge freeze map, 2026-07-24 — see Machine-specific values for why
#    some end up enabled-but-not-running; that is correct, don't "fix" it)
sudo apt-get install -y \
  openssh-server nfs-kernel-server hostapd openvpn sssd
sudo apt-get install -y dnsmasq || true          # postinst may fail to START it (port 53 vs systemd-resolved) — that's fine, it stays enabled-but-stopped
sudo systemctl enable --now nfs-server openvpn   # both run fine unconfigured
sudo systemctl enable ssh.socket                 # socket-activated ssh (noble default; explicit so re-runs converge)
sudo systemctl enable dnsmasq sssd               # enabled WITHOUT --now — need host config first
# hostapd is left exactly as apt sets it (masked) — that matches the station.

# 1+2. soil cron — ONLY on a station whose config defines
#    services.soil_script (myDevX1); every other station skips both steps.
# 1. confirm the camera creds are staged (see secrets/README.md) — path is
#    relative to wherever this repo is checked out:
test -f "$GENSYS_REPO_ROOT/secrets/cameras/soil.env" || echo "MISSING — restore secrets/ first"

# 2. add the cron line — composed from services.soil_script /
#    soil_cron_schedule, log path derived (.sh → .log). Never `sort` a
#    crontab (MAILTO=/PATH= assignments are order-sensitive); drop any
#    previous line for this script, keep the rest, append:
CUR="$(crontab -l 2>/dev/null || true)"   # `|| true`: a fresh box has no crontab yet
SOIL_LINE="$(cfg services.soil_cron_schedule "15 12 * * *") /bin/bash $(cfg services.soil_script) >> $(cfg services.soil_script | sed 's/\.sh$/.log/') 2>&1"
{ printf '%s\n' "$CUR" | grep -vF "$(cfg services.soil_script)" || true
  printf '%s\n' "$SOIL_LINE"; } | grep -v '^$' | crontab -

# 3. sync/backup tools (already installed via 01_base: syncthing, rclone,
#    duplicity, clonezilla, grsync). Syncthing FOLDERS are pre-configured
#    from the station config's syncthing.folders list (id/label/path per
#    folder): apply.sh enables the user syncthing.service, waits for the
#    API, then `syncthing cli config folders add` for each entry not
#    already present (idempotent — existing ids are skipped). Folder paths
#    are created only when their parent dir already exists; a path behind a
#    missing mount/bind (/proj, /mnt/*) is added anyway and stays errored
#    in the UI until that mount is applied — never invent a mount point.
systemctl --user enable --now syncthing.service
syncthing cli config folders add --id <id> --label <label> --path <path>   # per syncthing.folders entry
#    DEVICE pairing stays manual via the web UI (http://localhost:8384) —
#    the remote side must accept the new device id, which is interactive by
#    nature. With the folder ids already configured, accepting a paired
#    device's share offer links the folders straight up.

# 4. mdplanner.service — see 08_ai-agent-tools/README.md (same layer,
#    already covers this unit).

# 5. printer — one CUPS printer (MyPrinter). Trivial to redo via the
#    GNOME/Regolith printer settings GUI; not worth scripting a one-off.
```

Everything else in `/etc/cron.d`/`/etc/crontab` on the source host is stock
Ubuntu (`anacron`, `e2scrub_all`, `php`, `popularity-contest`, `sysstat`,
`zfsutils-linux`) — no action needed, noble ships the same defaults.

**Dropped per owner decision**: TeamViewer, AnyDesk, x11vnc/novnc/
websockify/RealVNC viewer, Remmina client — `11_tailscale` is now the one
remote-access layer. Add any of these back explicitly if they turn out to
still be needed; not part of the default flow.

---

## Verify

```bash
systemctl is-enabled ssh.socket nfs-server dnsmasq openvpn sssd  # all: enabled
systemctl is-enabled hostapd                                     # masked = correct
systemctl is-active nfs-server openvpn                           # both: active
crontab -l | grep soliAnal1    # only on a soil-opted station (myDevX1)
systemctl --user is-active syncthing.service          # active
syncthing cli config folders list                     # every syncthing.folders id from the station config
lpstat -p
```

---

## Machine-specific values

The soil cron line is composed by `apply.sh` from the active station
config's `services:` block (no repo file involved) and merged into the
crontab. It is a **per-station opt-in**: `apply.sh` has no built-in script
path, so a config without `services.soil_script` (any new station started
from `TEMPLATE.yaml`) gets no cron line at all — only `myDevX1.yaml`
defines it.

- **`services.soil_script`** — defining this key IS the opt-in; on myDevX1
  it's `/proj/soil/soliAnal1.sh`, and the log path is derived from it
  (`.sh` → `.log`).
- **`services.soil_cron_schedule`** (`15 12 * * *`, daily) — carried over as
  the default; revisit if the soil pipeline's cadence needs to change.
- **`services.printer_name`** (`MyPrinter`) — cosmetic, not actually
  consumed by any script; rename freely when re-adding via the GUI.
- **`syncthing.folders`** — the station's Syncthing folder list
  (`id`/`label`/`path` each), captured from the live `config.xml`;
  `apply.sh` pre-configures every entry via `syncthing cli`. Stations
  without the block skip this step entirely. Device ids are deliberately
  **not** in the config — a reinstalled box generates a new device key, so
  pairing is re-done via the web UI regardless.
- The `secrets/cameras/soil.env` existence check in `apply.sh` now resolves
  the repo root live (`$(cd "$HERE/.." && pwd)`) instead of a hardcoded
  clone path, so it works regardless of where this repo is checked out.

Four of the network services need host-side config before they actually
*do* anything — none of it is carried by this repo:

- **ssh** — noble is socket-activated: `ssh.socket` enabled, `ssh.service`
  disabled. That is both the apt default and the station's live state;
  don't "fix" the disabled service. Remote access policy note: Tailscale
  SSH (`11_tailscale`) is the kept remote path.
- **nfs** — `/etc/exports` on the station is stock (no exports); shares are
  ad-hoc. Add exports per box, `sudo exportfs -ra`.
- **dnsmasq** — station runs the stock config, so the unit is
  enabled-but-failed (port 53 is held by `systemd-resolved`). To make it
  actually serve, set `interface=`/`bind-interfaces` in
  `/etc/dnsmasq.conf`/`dnsmasq.d/` (or free port 53 via resolved's
  `DNSStubListener=no`) — a per-deployment choice, not scripted.
- **hostapd** — masked by apt until an AP config exists
  (`/etc/hostapd/hostapd.conf`), then `systemctl unmask --now hostapd`.
- **openvpn** — the meta-unit is active; actual tunnels come from
  `/etc/openvpn/{client,server}/*.conf`. Keys/certs are **secrets** — move
  them host-to-host via `secrets/` (see `secrets/README.md`), never commit.
- **sssd** — needs `/etc/sssd/` config (root-only, may hold domain
  credentials — same `secrets/` treatment) before it will start.

---

## Origin

`crontab -l`, `/etc/cron.d/`, `lpstat -p` captured 2026-07-23.

The network-services block is from the former `15-toolset` layer (merged in
2026-07-24), originally derived from the `query/snapshots/edge_2026-07-24`
freeze map (`11-apt-manual.txt`, `42-systemd-enabled.txt`) — that layer's
CLI-tools/Jupyter thirds went to `01_base`. Re-sync by re-running
`query/mapCurrentHost.sh` and re-diffing unit states.
