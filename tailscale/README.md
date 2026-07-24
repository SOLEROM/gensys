# Tailscale — reach your station from anywhere

Goal: reach your **station** (this workstation) from your **VPS Linux server** and
from your **Android phone/tablet** — securely, without opening any public ports,
port-forwarding, or exposing SSH to the internet.

The feature that makes this work is **Tailscale + Tailscale SSH**:

- **Tailscale** puts every device on a private mesh network (a *tailnet*). Each
  device gets a stable `100.x.y.z` IP that only your devices can reach.
- **MagicDNS** lets you use names instead of IPs — you reach the station as
  `station` (or `station.<your-tailnet>.ts.net`) from any device on the tailnet.
- **Tailscale SSH** lets the VPS and phone SSH into the station using your
  tailnet identity — no SSH keys to copy around, no password, no `sshd` exposed
  to the public internet. Access is governed by your tailnet ACL policy.

Everything below uses the same rule: **sign every device into the same Tailscale
account**, then they can all see each other.

---

## Part 1 — The station (the machine you want to reach)

This is the host you run `check-tailscale.sh` on.

### 1. Install

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

(On Ubuntu/Debian this adds the official repo and installs the `tailscale`
package + `tailscaled` service.)

### 2. Bring it up with SSH enabled and a stable name

```bash
sudo tailscale up --ssh --hostname=station
```

- `--ssh` turns this machine into a Tailscale SSH **server** — the VPS and phone
  can now SSH in as your tailnet identity.
- `--hostname=station` gives it the MagicDNS name `station` so you never have to
  remember its IP.

A browser link is printed the first time — open it and authenticate.

> **Server tip:** so the station doesn't drop off the tailnet when its key
> expires, open the [admin console](https://login.tailscale.com/admin/machines),
> find the `station` machine → **⋯** → **Disable key expiry**.

### 3. Enable MagicDNS (once per tailnet)

In the admin console → **DNS** → enable **MagicDNS**. This is what makes the
`station` name resolve on every device.

### 4. Verify

```bash
./check-tailscale.sh
```

You should see PASS for install, daemon, login, MagicDNS, and Tailscale SSH.

---

## Part 2 — VPS Linux server (accessing the station)

### 1. Install + join the tailnet

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --hostname=vps
```

Sign in with the **same account** as the station. (`--ssh` here is optional — it
just lets you *also* SSH *into* the VPS the same way; it's handy, keep it.)

### 2. Reach the station

```bash
# Shell into the station (Tailscale SSH — no keys, no password):
tailscale ssh <your-user>@station

# ...or plain ssh, which resolves via MagicDNS over the tailnet:
ssh <your-user>@station

# By IP, if you prefer:
tailscale ip -4        # on the station, shows its 100.x address
ssh <your-user>@100.x.y.z
```

Any TCP service on the station is now reachable from the VPS at `station:<port>`
(e.g. a local web app on `station:3000`, a database on `station:5432`) with no
firewall changes.

### 3. Verify the VPS side

Copy `check-tailscale.sh` to the VPS and run it in **client mode** (the VPS
doesn't need to be an SSH *server*, so SSH-server-off is not treated as an error):

```bash
./check-tailscale.sh --client
```

---

## Part 3 — Android phone / tablet

### 1. Install the app

Install **Tailscale** from the Google Play Store, open it, and **sign in with the
same account**. Toggle the VPN **on** and approve the connection prompt.

Once connected, the phone is on the tailnet and MagicDNS works — `station`
resolves automatically.

### 2. Reach the station from Android

- **SSH:** install any SSH client (Termius, JuiceSSH, or Termux with `openssh`)
  and connect to host `station` (or `station.<your-tailnet>.ts.net`, or the
  `100.x` IP), user `<your-user>`.
  - Tailscale SSH's `check` policy (see below) may pop a browser tab the first
    time to confirm your identity — approve it and the session opens.
- **Web / other services:** just browse to `http://station:<port>` in any app.
- **Files:** use **Taildrop** — in the Android app, share a file and pick
  `station` as the target; it lands in the station's Taildrop inbox
  (`tailscale file get .` on the station, or auto-accept if configured).

---

## Tailscale SSH access policy (ACLs)

Tailscale SSH is gated by an `ssh` block in your tailnet policy
([admin console → Access controls](https://login.tailscale.com/admin/acls)).
Personal tailnets ship with a working default similar to:

```json
"ssh": [
  {
    "action": "check",
    "src":    ["autogroup:member"],
    "dst":    ["autogroup:self"],
    "users":  ["autogroup:nonroot", "root"]
  }
]
```

- `autogroup:self` = you may SSH to your **own** devices. Since the station, VPS,
  and phone are all on your account, this already permits everything you need.
- `action: "check"` = periodic browser re-verification. If you want fully
  non-interactive SSH from the VPS (e.g. for scripts/cron), change that one rule
  to `"action": "accept"`.

---

## Quick verification cheatsheet

```bash
tailscale status          # who's on the tailnet, who's online
tailscale ip -4           # this host's tailnet IP
tailscale ping station    # end-to-end reachability test
./check-tailscale.sh      # full local install + config audit (this repo)
./list-online.sh          # pretty table of ONLINE tailnet devices (this repo)
./list-online.sh --all    #   ...include offline devices + last-seen
./list-online.sh --ips-only  # just the online tailnet IPs (script-friendly)
```

Admin console: <https://login.tailscale.com/admin/machines>

---

## Security notes

- **No public exposure.** Nothing here opens a port on the public internet.
  Access is limited to devices signed into your tailnet and allowed by ACLs.
- **Disable key expiry** on always-on hosts (station, VPS) so they don't silently
  drop off; leave it enabled on the phone.
- **Least privilege.** Tighten the `ssh` ACL (`users`, `src`, `dst`) if you ever
  add devices or users you don't fully trust.
- **Lock it down further** (optional): enable *tailnet lock* to require that new
  devices be signed by an existing trusted node before they can join.
