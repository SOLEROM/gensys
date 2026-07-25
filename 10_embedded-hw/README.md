# 10_embedded-hw — optional, on-demand only (NOT part of the default install)

**Per owner decision, this layer is not applied by default, ever.** It's
not gated with a yes/no question during the standard run either — it's
simply skipped, silently, unless the owner explicitly asks for it by name at
some later point. `make all` intentionally excludes `10_embedded-hw`; only
`make 10_embedded-hw` (run by name) applies it. `CLAUDE_CONSUMER.md` does not
probe for or ask about this layer's hardware during its normal Step 1/2.

Documented here purely as a reference of what exists on the source host, in
case it's ever wanted on the new one.

---

## What's here (reference only, not installed by default)

- **Arduino**: `arduino-cli` + IDE AppImage.
- **OpenOCD** + `60-openocd.rules` (udev).
- **Android SDK/emulator** + `51-android.rules` (udev). Note: this host's
  live `.zshrc` carries `ANDROID_HOME`/`ANDROID_SDK_ROOT`/Gradle `PATH`
  exports unconditionally today — those are intentionally **not** in
  `05_shell`'s `.zshrc` snapshot; they belong here instead and would
  only get added back if this layer is ever built out.
- **Xilinx Vivado/Vitis** — proprietary, license-gated, not automatable.
  Installer already staged at `/data/sysadmin/local/*` if ever needed.
- **Hailo AI accelerator** (`hailort-pcie-driver`) + `phosphobot` + servo
  tooling.
- **Serial/USB/camera diagnostics**: `v4l-utils`, `evtest`, `gpiod`,
  `minicom` (w/ a Radxa Rock 5 profile), `picocom`, `can-utils`.
- **`jtop`/`jetson_release`/`jetson_swap`** — found enabled+running on this
  host despite no local Jetson hardware present. Confirm this is
  intentional remote-management before ever re-enabling; not assumed here.
- **Generic (non-serial-specific) udev rules**: `20-hw1.rules`,
  `50-myusb.rules`, `69-mtp.rules`, `99-usb.rules` — the last two live in
  `14_udev` (moved out of `13_misc` 2026-07-24); not duplicated here.

## If this is ever built out

- Add a `files/` dir + a proper `apply.sh` mirroring the package/udev-rule
  list above, following the same convention as every other layer.
- Wire it into the Makefile as `make 10_embedded-hw` only — **do not** add
  it to `all`'s dependency list.
- Large proprietary installers (Vivado, VirtualBox extension pack, Ghidra,
  various `.deb`/`.AppImage`) already staged at `/data/sysadmin/local/*` —
  point at that folder rather than re-vendoring multi-GB files into this
  repo.

---

## Origin

Investigation captured 2026-07-23. Not mined into `files/` — this layer
stays documentation-only until explicitly requested.
