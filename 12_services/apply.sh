#!/usr/bin/env bash
# 12_services/apply.sh — mirrors this layer's README.md Apply section.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"

echo "==> network service packages (absorbed from the former 15-toolset)"
sudo apt-get install -y \
  openssh-server nfs-kernel-server hostapd openvpn sssd
# dnsmasq separately: its postinst tries to START it, port 53 is usually
# held by systemd-resolved on a stock box, and a failed postinst would
# abort the whole layer — enabled-but-stopped is the intended end state.
sudo apt-get install -y dnsmasq || true
command -v dnsmasq >/dev/null 2>&1 || { echo "ERROR: dnsmasq did not install" >&2; exit 1; }

# Match the source station's unit states (edge freeze map, 2026-07-24):
# - ssh: socket-activated — enable ssh.socket explicitly (apt's noble
#   default does this on a fresh install; the explicit call makes re-runs
#   converge too).
# - hostapd: stays masked (apt default) until an AP config exists — not
#   touched here, so an owner who deliberately unmasked it isn't fought.
# - dnsmasq/sssd: enabled but cannot START until host config is restored
#   (see README's Machine-specific values) — so enable WITHOUT --now, or a
#   bare box would abort right here.
sudo systemctl enable --now nfs-server openvpn
sudo systemctl enable ssh.socket
sudo systemctl enable dnsmasq sssd

# Soil-monitoring cron — one station's personal workload (myDevX1), not a
# repo-wide default. The opt-in is the station config itself: only a yaml
# that defines services.soil_script gets the cron line; no key → the whole
# block is skipped, nothing touches the crontab.
SOIL_SCRIPT="$(cfg services.soil_script)"
if [ -z "$SOIL_SCRIPT" ]; then
  echo "==> cron: no services.soil_script in the station config — soil cron not installed (per-station opt-in)"
else
  if [ ! -f "$GENSYS_REPO_ROOT/secrets/cameras/soil.env" ]; then
    echo "WARNING: secrets/cameras/soil.env missing — restore secrets/ before" >&2
    echo "the soil cron job will actually work (it will fail loudly at cron time otherwise)." >&2
  fi
  SOIL_LOG="${SOIL_SCRIPT%.sh}.log"
  SOIL_CRON_SCHEDULE="$(cfg services.soil_cron_schedule "15 12 * * *")"
  echo "==> cron: installing the soil job ($SOIL_CRON_SCHEDULE $SOIL_SCRIPT)"
  # The line is composed here, not shipped as a repo file — an opted-out
  # station's checkout carries no trace of this workload.
  # NOTE the shape: `crontab -l` exits 1 when no crontab exists yet (the
  # fresh-box case!) and set -e would kill the old subshell version right
  # there; and the crontab must never be sort'ed — order matters for
  # MAILTO=/PATH= assignments. Drop any previous soil line for this script
  # (schedule/log may have changed), keep the rest as-is, append.
  CUR="$(crontab -l 2>/dev/null || true)"
  SOIL_LINE="$SOIL_CRON_SCHEDULE /bin/bash $SOIL_SCRIPT >> $SOIL_LOG 2>&1"
  { printf '%s\n' "$CUR" | grep -vF "$SOIL_SCRIPT" || true
    printf '%s\n' "$SOIL_LINE"
  } | grep -v '^$' | crontab -
fi

# Syncthing — pre-configure this station's folders from the station config
# (the syncthing.folders list). Device pairing stays a manual web-UI step
# (http://localhost:8384) — the remote side's acceptance is interactive by
# nature — but with folder ids/labels/paths already in place, a paired
# device offering those same folder ids links straight up instead of each
# folder being retyped by hand.
N_FOLDERS=0
if [ -n "${CONFIG_FILE:-}" ] && [ -f "$CONFIG_FILE" ]; then
  N_FOLDERS="$(yq e '.syncthing.folders | length' - < "$CONFIG_FILE" 2>/dev/null || echo 0)"
fi
# The service itself is enabled regardless of folder pre-config — the
# README's Verify expects an active syncthing on every station that has it
# installed; only the folders add loop is per-station opt-in.
if ! command -v syncthing >/dev/null 2>&1; then
  echo "WARNING: syncthing not installed (01_base provides it) — skipping syncthing entirely." >&2
elif [ "${N_FOLDERS:-0}" = "0" ]; then
  systemctl --user enable --now syncthing.service 2>/dev/null || \
    echo "WARNING: could not start the user syncthing.service (no user session bus?)." >&2
  echo "==> syncthing: enabled; no syncthing.folders in the station config — nothing to pre-configure"
elif ! systemctl --user enable --now syncthing.service 2>/dev/null; then
  echo "WARNING: could not start the user syncthing.service (no user session bus?)." >&2
  echo "Start it, then re-run 'make 12_services' to pre-configure the folders." >&2
else
  echo "==> syncthing: pre-configuring $N_FOLDERS folder(s) from the station config"
  # first start generates device keys + config — wait for the API to answer
  for _ in $(seq 1 30); do
    syncthing cli show system >/dev/null 2>&1 && break
    sleep 1
  done
  EXISTING="$(syncthing cli config folders list 2>/dev/null || true)"
  for i in $(seq 0 $((N_FOLDERS - 1))); do
    FID="$(cfg "syncthing.folders[$i].id")"
    FPATH="$(cfg "syncthing.folders[$i].path")"
    FLABEL="$(cfg "syncthing.folders[$i].label")"
    { [ -n "$FID" ] && [ -n "$FPATH" ]; } || continue
    if printf '%s\n' "$EXISTING" | grep -qxF -- "$FID"; then
      echo "    $FID ($FPATH) — already configured, skipping"
      continue
    fi
    # Create the folder path only when its parent already exists — never
    # invent a mount point (the /proj bind, /mnt/*): such folders stay
    # errored in the UI until the mount/bind is applied, the honest state.
    if [ ! -d "$FPATH" ]; then
      if [ -d "$(dirname "$FPATH")" ]; then
        mkdir -p "$FPATH" 2>/dev/null || \
          echo "    WARNING: could not create $FPATH (permission denied — root-owned parent?) — adding the folder anyway; it shows an error in the UI until it's created by hand (e.g. sudo mkdir -p + chown)" >&2
      else
        echo "    WARNING: parent of $FPATH doesn't exist (missing mount/bind?) — adding the folder anyway; it shows an error in the UI until the path exists" >&2
      fi
    fi
    syncthing cli config folders add --id "$FID" --label "${FLABEL:-$FID}" --path "$FPATH"
    echo "    added $FID ($FPATH)"
  done
fi

echo "==> done. Syncthing device pairing and the printer are manual/GUI steps — see README.md."
