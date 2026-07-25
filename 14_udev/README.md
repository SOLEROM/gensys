# 14_udev — device-specific udev rules, **optional/on-demand only**

**Not applied by default on any new station** — not part of `make all`, not
a `CLAUDE_CONSUMER.md` step, not even asked about (same treatment as
`10_embedded-hw`). Run `make 14_udev` (or `./14_udev/apply.sh`) explicitly
on a station that actually has these devices and wants these rules.

Moved out of `13_misc` on 2026-07-24 (owner decision): both rules target
specific hardware/workflows that most stations won't have, so they don't
belong in the always-applied misc layer.

## Purpose

- `69-mtp.rules` — Samsung MTP devices (`idVendor 04e8`): mode `0660`
  (the old snapshot said `6860` — not a valid octal mode, udev rejected it
  at event time; fixed 2026-07-25), group `plugdev`, for phone file
  transfer. `apply.sh` also adds the user to `plugdev` (re-login needed).
- `99-usb.rules` — one specific SanDisk USB stick
  (`idVendor 0781 / idProduct 5595`): world-writable mode and a
  `/dev/myusbdevice` symlink. The old `RUN+= {{HOME}}/sys/test.sh` hook was
  **dropped** (2026-07-25): udev `RUN` executes as root, and a root-run
  hook living under a user-writable `$HOME` path is a local privilege
  escalation; the script also never existed on the source host.

---

## Prerequisites

None (udev is part of systemd, always present).

---

## Files in this layer

| repo path | target on fresh box |
|---|---|
| `files/udev/69-mtp.rules` | `/etc/udev/rules.d/69-mtp.rules` |
| `files/udev/99-usb.rules` | `/etc/udev/rules.d/99-usb.rules` (rendered — `{{HOME}}`) |

---

## Apply

```bash
sudo install -m 0644 -o root -g root files/udev/69-mtp.rules /etc/udev/rules.d/69-mtp.rules

# 99-usb.rules carries {{HOME}} — render via mktemp (never a fixed /tmp
# name for something sudo-installed into /etc), install root-owned:
TMP="$(mktemp)"
render_template files/udev/99-usb.rules "$TMP" "HOME=$HOME"
sudo install -m 0644 -o root -g root "$TMP" /etc/udev/rules.d/99-usb.rules
rm -f "$TMP"

# plugdev membership (69-mtp grants the device to that group):
sudo usermod -aG plugdev "$(id -un)"    # takes effect after re-login

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb   # re-evaluate already-plugged devices
```

---

## Verify

```bash
ls /etc/udev/rules.d/ | grep -E '69-mtp|99-usb'
# plug the device in, then:
udevadm info -q property -n /dev/myusbdevice 2>/dev/null | head || true
```

---

## Machine-specific values

- **The device IDs themselves** — `04e8` (Samsung) and `0781:5595` (that
  one SanDisk stick) are the point of this layer being on-demand: check
  `lsusb` for the actual devices on the target station and adjust/drop
  rules accordingly.
- **`99-usb.rules`'s `{{HOME}}`** — still rendered at apply time (kept for
  any future $HOME-relative value), though the `RUN+=` hook that used it is
  gone (see Purpose). If a plug-in hook is ever wanted, ship the script
  root-owned under `/usr/local/lib/` and point `RUN+=` there — never at a
  path the login user can write.

---

## Origin

`/etc/udev/rules.d/{69-mtp,99-usb}.rules`, captured 2026-07-23 from the
source host (originally part of `13_misc`; split out 2026-07-24).
