# 11_tailscale — Tailscale (the one kept remote-access layer)

## Purpose

Per owner decision, Tailscale is the kept/promoted remote-access solution;
TeamViewer, AnyDesk, and the VNC stack are dropped from the default scope
entirely. This laptop is one of 4 nodes on the
owner's tailnet today: this station, a VPS (`vps1` — see
`secrets/hosts.env`), and two mobile devices.

Goal: reach this station from the VPS and from a phone/tablet — securely,
with no public ports, no port-forwarding, no SSH exposed to the internet.
The feature that makes this work is **Tailscale + Tailscale SSH**:

- **Tailscale** puts every device on a private mesh network (a *tailnet*).
  Each device gets a stable `100.x.y.z` IP only your own devices can reach.
- **MagicDNS** lets you use names instead of IPs on the tailnet.
- **Tailscale SSH** lets the VPS/phone SSH into this station using tailnet
  identity — no keys to copy, no password, no `sshd` exposed publicly.
  Access is governed by the tailnet's ACL policy (see below).

---

## Prerequisites

Tailscale's apt repo + keyring — already added in `01_base` (§ third-party
sources); repeated here for completeness in case this layer is applied
standalone:

```bash
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
sudo apt-get update
sudo apt-get install -y tailscale
```

`check-tailscale.sh` also wants `jq` (falls back to `python3`, already
installed by `01_base`) for reading `tailscale status --json`.

---

## Files in this layer

| repo path | target on fresh box |
|---|---|
| `files/check-tailscale.sh` | `<sysadmin_dir>/01_scripts/tailscale/check-tailscale.sh` |
| `files/list-online.sh` | `<sysadmin_dir>/01_scripts/tailscale/list-online.sh` |

`<sysadmin_dir>` = `station.sysadmin_dir` from `../00_configs/<name>.yaml`
(default `/data/sysadmin`, on the persistent `/data` partition — needs
`04_storage` applied first) — same knob `05_shell` uses.

No ACL/exit-node config file to carry — none in use on this host as of
capture; Tailscale's own state lives under `/var/lib/tailscale`, not
snapshotted here. A fresh `tailscale up` login re-establishes this node's
identity on the tailnet.

`check-tailscale.sh` audits the local install/login/MagicDNS/SSH-server
state; `list-online.sh` prints a table of who's currently on the tailnet.
Both are read-only/diagnostic — safe to re-run any time. Migrated in from
the older, separate `/data/proj/myGits/syso/gensys` repo (pre-`gensys`
convention) — see the Origin section.

---

## Apply

```bash
SYSADMIN_DIR="$(cfg station.sysadmin_dir /data/sysadmin)"
# default root is on /data (root-owned mount root on a fresh box) — same
# ownership guard as 05_shell, in case this layer runs first:
if [ ! -d "$SYSADMIN_DIR" ] && ! mkdir -p "$SYSADMIN_DIR" 2>/dev/null; then
  sudo mkdir -p "$SYSADMIN_DIR"; sudo chown "$(id -un):$(id -gn)" "$SYSADMIN_DIR"
fi
mkdir -p "$SYSADMIN_DIR/01_scripts/tailscale"
cp files/check-tailscale.sh files/list-online.sh "$SYSADMIN_DIR/01_scripts/tailscale/"
chmod +x "$SYSADMIN_DIR/01_scripts/tailscale/"*.sh

sudo systemctl enable --now tailscaled
sudo tailscale up --ssh --hostname=<this-host-name>   # interactive login (browser or QR) — no secret to store
```

- `--ssh` turns this machine into a Tailscale SSH **server** — the VPS and
  phone can SSH in as your tailnet identity, no keys/passwords involved.
- `--hostname=<this-host-name>` gives it a stable MagicDNS name. Pick
  something you'll remember (e.g. `station`); it doesn't have to match the
  local hostname.

An unattended authkey is a possible later upgrade (store it under
`secrets/` if ever adopted — see `secrets/README.md`) — not needed for a
manual, in-person reinstall.

**Server tip:** so this node doesn't drop off the tailnet when its key
expires, open the [admin console](https://login.tailscale.com/admin/machines),
find this machine → **⋯** → **Disable key expiry**. Also enable **MagicDNS**
tailnet-wide (admin console → DNS) if not already on — one-time, per
tailnet, not per device.

### Reaching this station from the other 3 nodes

```bash
# from vps1 (already joined the same tailnet with its own `tailscale up`):
tailscale ssh <user>@<this-host-name>     # Tailscale SSH — no keys, no password
ssh <user>@<this-host-name>               # plain ssh, resolves via MagicDNS
ssh <user>@100.x.y.z                      # by tailnet IP if you prefer

# from Android (Tailscale app installed, signed into the same account,
# VPN toggle on): any SSH client (Termius/JuiceSSH/Termux+openssh) connecting
# to <this-host-name> or the 100.x IP; Taildrop for file transfer.
```

Any TCP service on this station is reachable from the other tailnet nodes at
`<this-host-name>:<port>` with no firewall changes — e.g. `cldlab` on
`:6002` (see `08_ai-agent-tools`).

### Tailscale SSH access policy (ACLs)

Gated by an `ssh` block in the tailnet policy (admin console → *Access
controls*). Personal tailnets ship with a working default similar to:

```json
"ssh": [
  { "action": "check", "src": ["autogroup:member"],
    "dst": ["autogroup:self"], "users": ["autogroup:nonroot", "root"] }
]
```

`autogroup:self` already covers "SSH between my own devices" (station, vps1,
phones). `action: "check"` means periodic browser re-verification; change
that one rule to `"action": "accept"` only if you need fully
non-interactive SSH from a script/cron on `vps1`.

---

## Verify

```bash
tailscale status              # this node + the other 3 (vps1, two mobile devices)
tailscale ip -4                # this node's tailnet IP
/data/sysadmin/01_scripts/tailscale/check-tailscale.sh   # full local install/config audit (default sysadmin_dir)
/data/sysadmin/01_scripts/tailscale/list-online.sh       # who's online right now
```

`check-tailscale.sh` (no args) expects Tailscale SSH server **on** (station
mode). Run it with `--client` on a node that's only meant to reach out
(e.g. if you ever run it against `vps1`), where an SSH server isn't
expected.

---

## Machine-specific values

- **Tailnet identity** — re-established via interactive login, not
  restorable from a file. The old node entry for this laptop may need
  manual cleanup on the tailnet admin console if it shows up twice after
  reinstall.
- **`--hostname=`** — pick per box; doesn't have to match the OS hostname.
  `apply.sh` now prints the suggested command with
  `station.tailscale_hostname` (from `../the active station's 00_configs yaml`) filled in —
  `tailscale up` itself still has to be run by hand (interactive login).
- No ACLs/exit-node config to carry — confirmed none in use on this host as
  of this capture.

---

## Origin

`tailscale status`/`tailscale version` captured 2026-07-23 (4-node tailnet:
this laptop, `vps1`, two mobile devices). `files/check-tailscale.sh`,
`files/list-online.sh`, and this README's Part-1/2/3 setup instructions
migrated in 2026-07-24 from `/data/proj/myGits/syso/gensys/tailscale/` (an
older, separate repo predating the `gensys` layered convention).
