# 17_gdrive — Google Drive remote (rclone), optional, on-demand only (NOT part of the default install)

**Per owner decision, this layer is not applied by default, ever.** It's
not gated with a yes/no question during the standard run either — it's
simply skipped, silently, unless the owner explicitly asks for it by name
at some later point. `make all` intentionally excludes `17_gdrive`; only
`make 17_gdrive` (run by name) touches it — and until an `apply.sh` exists,
that just prints this README. `CLAUDE_CONSUMER.md` does not probe for or
ask about this layer during its normal Step 1/2.

---

## Purpose

Configure an `rclone` remote pointed at a Google Drive account, for
stations whose tooling pushes local data up to Drive — e.g. the
soil-monitoring pipeline's `driveSync.sh` (`/proj/soil/driveSync.sh`),
which expects a remote literally named `gdrive:` and fails at runtime
without it.

---

## Prerequisites

```bash
sudo apt-get install -y rclone
```

A browser + display **on the box doing the OAuth step** — `rclone config
create` opens a local callback server and tries to launch a browser via
`xdg-open`. On a genuinely headless box, use the "authorize elsewhere"
fallback below instead.

---

## Files in this layer

None. This layer only ever writes `~/.config/rclone/rclone.conf` (created
by `rclone` itself, mode `600`) — no repo-tracked files ship here. The
OAuth token is a live per-station secret and must never be committed.

---

## Apply

Remote name is a station choice; default to `gdrive` unless something on
that station expects a different name (check for `gdrive:` literals in
scripts first, e.g. `grep -r 'gdrive:' /proj`).

**Headed box** (browser available locally) — opens a browser window, sign
in and click "Allow"; `rclone` blocks waiting for the local OAuth callback:

```bash
rclone config create gdrive drive scope=drive
```

**Headless box** (no local browser) — authorize from a machine that has
one, then hand the resulting token to the headless box:

```bash
# 1. on a machine with a browser + rclone installed:
rclone authorize "drive"
# 2. paste the JSON it prints as the token= value, on the headless box:
rclone config create gdrive drive scope=drive token='<pasted JSON>'
```

`scope=drive` grants full read/write access to the whole Drive, not just
files rclone itself created — needed because these pipelines sync into a
pre-existing shared folder they don't own. If a station only ever needs
read-only access, use `scope=drive.readonly` instead.

---

## Verify

```bash
rclone listremotes    # gdrive:
rclone lsd gdrive:     # lists real folders — confirms the token actually works
```

---

## Machine-specific values

- **Remote name** — hardcoded to `gdrive` in the example above because
  that's what `/proj/soil/driveSync.sh` expects; a station not running
  that pipeline can use any name.
- **The OAuth token** — lives only in `~/.config/rclone/rclone.conf`
  (mode `600`), never captured into this repo. Treat it like any other
  credential: if it's ever exposed (e.g. printed to a log or terminal
  session), revoke it at https://myaccount.google.com/permissions and
  re-run `rclone config reconnect gdrive:`.

---

## If this is ever built out

- Add an `apply.sh` that: checks `rclone listremotes` for the target name
  first (idempotent — skip if already configured); installs `rclone` via
  apt if missing; runs `rclone config create <name> drive scope=drive`;
  detects a missing `$DISPLAY`/browser and prints the headless
  `rclone authorize` fallback instead of hanging on the OAuth wait.
- Wire it into the Makefile as `make 17_gdrive` only — **do not** add it
  to `all`'s dependency list, same treatment as `10_embedded-hw`/`14_udev`.
- The remote name and `scope` would become station-config values
  (`../00_configs/<name>.yaml`), same pattern as `04_storage`'s
  machine-specific values.

---

## Origin

Set up manually on the soil-pipeline host, 2026-07-26, to unblock
`/proj/soil/soliAnal1.sh`'s final `driveSync.sh` step (that station's
`rclone.conf` had no `gdrive:` remote at all). Documented here so a future
fresh-box rebuild has the exact steps instead of rediscovering them.
