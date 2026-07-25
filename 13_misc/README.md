# 13_misc — fonts, git identity, ssh config pattern, browsers, locale

## Purpose

The remaining small, independent items that don't warrant their own layer.
(udev rules used to live here too — moved to the optional/on-demand
`../14_udev/` layer on 2026-07-24, since they're device-specific and
shouldn't apply to every new station by default.)

---

## Prerequisites

None.

---

## Files in this layer

| repo path | target on fresh box |
|---|---|
| `files/fonts/JetBrainsMono/*.ttf` | `~/.local/share/fonts/JetBrainsMono/` |
| `files/gitconfig` | `~/.gitconfig` |
| `files/ssh_config_pattern` | appended to `~/.ssh/config` (pattern only, not real hosts) |

---

## Apply

```bash
# fonts
mkdir -p ~/.local/share/fonts/JetBrainsMono
cp files/fonts/JetBrainsMono/*.ttf ~/.local/share/fonts/JetBrainsMono/
fc-cache -f

# git identity — no secrets (git-lfs filter, git-cola spellcheck off);
# name/email templated from the active station's 00_configs yaml's git.name/git.email
render_template files/gitconfig ~/.gitconfig "GIT_NAME=$(cfg git.name)" "GIT_EMAIL=$(cfg git.email)"

# ssh config *pattern* (not keys/hosts) — the keys themselves stay under
# secrets/ssh/ and are consumed IN PLACE by the ssh-add aliases in
# ../02_aliases/alias.bashrc (git.solerom/git.trip); nothing copies them to
# ~/.ssh. Guarded append — a re-run must not duplicate the block:
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/config
grep -qF "Session Manager" ~/.ssh/config || cat files/ssh_config_pattern >> ~/.ssh/config

# udev rules — moved to ../14_udev/ (optional, on-demand only)

# locale/keyboard — station.timezone in the active station's 00_configs yaml (Asia/Jerusalem
# on this station); keySetEng/keySetHeb aliases (now in
# ../02_aliases/alias.bashrc) imply bilingual English/Hebrew input, set the
# input sources via GNOME Settings > Region & Language (interactive, not
# scripted — it's a one-time GUI toggle)
sudo timedatectl set-timezone "$(cfg station.timezone Asia/Jerusalem)"

# Hebrew font coverage for the bilingual input above (culmus — added
# 2026-07-24 from the query/snapshots/zenbook_2026-07-24 diff)
sudo apt-get install -y culmus

# browsers — plain apt installs (already in 01_base): firefox, google-chrome-stable,
# thunderbird. Firefox *bookmarks* specifically: see ../15_firefox/ (backup.sh
# already run on the old station; restore.sh stages them on the new one).
```

**NetworkManager Wi-Fi — deliberately not scripted.** ~30 named SSIDs plus
77 duplicate "Wired connection N" profiles (an NM dock/cable-reconnect bug)
exist on the source host. PSKs live in root-only files; re-join Wi-Fi
manually on the fresh box rather than migrating connection profiles.
Cleaning up the 77 duplicates is worth doing on the *old* host regardless,
via `nmcli connection delete`, independent of this reinstall.

---

## Verify

```bash
fc-list | grep -i jetbrainsmono | head -3
fc-list | grep -i culmus | head -3
git config --get user.name; git config --get user.email
cat ~/.ssh/config
timedatectl | grep "Time zone"
```

---

## Machine-specific values

- **`files/gitconfig`** — `{{GIT_NAME}}`/`{{GIT_EMAIL}}` templates, rendered
  by `apply.sh` from `git.name`/`git.email` in `../the active station's 00_configs yaml`.
  This station's `git.email` is itself still the unresolved
  `{ID}+{username}@users.noreply.github.com` placeholder (see the comment
  in that YAML file) — fill in your real GitHub noreply email there.
- **Timezone/locale** (`station.timezone` in `../the active station's 00_configs yaml`,
  `Asia/Jerusalem` on this station) — change there for a station in a
  different timezone.
- **`.xbindkeysrc`/`.xmodmap-<user>`** — legacy X11-level keybindings/keymap
  from before i3 `config.d` existed. Still an open question (flagged in
  `02_aliases/README.md` too) whether these are worth carrying at all now that
  Regolith/i3 covers keybindings — not included here pending that decision.

---

## Origin

`~/.gitconfig`, `/data/sysadmin/local/JetBrainsMono-2.242/fonts/ttf/`,
`~/.ssh/config`, `timedatectl show`, `nmcli -t -f NAME,TYPE connection show`
— all captured 2026-07-23. (The udev rules captured alongside these now
live in `../14_udev/`.) `culmus` added 2026-07-24 from
`query/snapshots/zenbook_2026-07-24` — pairs with the bilingual
English/Hebrew input already noted above.
