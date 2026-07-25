# 00_configs/ — per-station, non-secret parameters

One YAML file per station this repo has ever been used to build. Every
layer's `apply.sh` reads its per-machine defaults from here instead of
carrying them as hardcoded literals — the thing that used to require
hand-editing ~10 files to onboard a new box is now "copy a YAML file, fill
in a dozen values."

```
00_configs/
  load.sh              # shared loader: cfg(), render_template() — sourced by every layer's apply.sh
  myDevX1/             # myDevX1's per-station folder — everything needed to define
                       # and rebuild a station from this dev box. GIT-IGNORED as one
                       # folder (personal layout; working-tree copy only):
    myDevX1.yaml       #   the station's real values
    host_devX1.md      #   end-state companion doc: what the finished box looks
                       #   like, layer by layer
    myDevX1_aliases    #   host-specific aliases — the personal-path stuff split
                       #   out of ../02_aliases/alias.bashrc
  myClean.yaml         # lean general-purpose profile for a future fresh box (tracked)
  TEMPLATE.yaml        # station-agnostic skeleton — copy this for the next station
  README.md            # this file
```

Separation contract between them:

- **`<station>.yaml`** (like `myDevX1.yaml`, `myClean.yaml`) is a per-station
  record: real UUIDs, real paths, real layer choices for that box. One file
  per station. Tracked by default (`myClean.yaml` is) — but a station whose
  config records the personal folder/agent layout can instead keep all its
  files in a git-ignored per-station subfolder (`myDevX1/` is one, see the
  root `.gitignore`), traveling only with the manual working-tree copy, like
  `../secrets/`. `load.sh` finds station yamls both flat and one level down.
- **`host_<station>.md`** (optional) is that station's end-state companion
  doc — the layer-by-layer description of what the fully-built box looks
  like (`host_devX1.md` for myDevX1). It shares the yaml's tracked/ignored
  status: same personal detail, same treatment.
- **`<station>_aliases`** (optional) is that station's host-specific alias
  file — aliases naming a project directory, port, or peripheral that only
  exists on that one box, split out of the general, portable
  `../02_aliases/alias.bashrc` (see that folder's README, "General vs.
  host-specific"). Same tracked/ignored treatment as the yaml. Wired since
  2026-07-25: `05_shell/apply.sh` derives it from the active yaml
  (`${CONFIG_FILE%.yaml}_aliases` — works flat or in a per-station
  subfolder) and installs it as `<sysadmin_dir>/00_bashrc/station_aliases`,
  which `alias.bashrc` sources **last** (it depends on vars set there:
  `$sys`, `$data`, `$proj`, `$tasks_script`). Stations without one get
  nothing installed; a stale copy from a previous station is removed.
- **`TEMPLATE.yaml`** is a clean skeleton that assumes nothing about any
  existing station: every value is a `<placeholder>` or a neutral repo
  default, and layers carrying one station's personal workloads
  (`08_ai-agent-tools`, `12_services`) default to `"no"` with their config
  sections commented out. Station values are never copied back into it —
  when a new key is added to the repo, the template gets the placeholder,
  the station files get the real values.

## What lives here vs. `../secrets/`

- **`00_configs/*.yaml`** — structural/identity values: UUIDs, ports, paths,
  usernames, timezone, wallpaper choice. Not sensitive, safe to commit —
  it's the same kind of information already committed elsewhere in every
  layer's README, just centralized and machine-readable now.
- **`../secrets/`** — actual credentials (passwords, API tokens, private
  keys). Git-ignored, moved host-to-host manually. See `../secrets/README.md`.
  Not touched by this folder or by this change.

## How it's consumed

Every layer's `apply.sh` does:

```bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../00_configs/load.sh"

LUKS_UUID="${LUKS_UUID:-$(cfg storage.luks_uuid)}"
```

Precedence, highest first: **an env var you pass on the command line**
(unchanged from before this existed — see the root `Makefile`'s header
comment) → **the active config file** → **the script's own built-in
literal fallback** (a generic default like `16G` swap, not a value tied to
any specific station).

`cfg` paths are yq expressions, so indexed list entries work too —
`12_services/apply.sh` reads `syncthing.folders[0].id`, `[0].path`, … to
pre-configure Syncthing folders (the one list-shaped key in the config).

`00_configs/load.sh` also installs `yq` (mikefarah, via snap) if it isn't on
the box yet — same self-sufficiency pattern `04_storage/apply.sh` already
uses for `cryptsetup`.

Files that can't do shell expansion at all (systemd units, udev rules,
`.gitconfig`) are rendered from `{{PLACEHOLDER}}`-tagged templates via
`render_template` (the same idea `06_desktop-i3/files/Xresources` already
uses for `{{WALLPAPER}}`) — the tracked file keeps its normal name, it just
has tokens inside instead of one station's literal values.

## Which config file is active

Resolution order in `load.sh` — it never guesses between stations:

1. **`GENSYS_CONFIG` if set** — must exist; a typo'd path is a hard error
   (not a silent fallback to another station's values):
   ```bash
   GENSYS_CONFIG=00_configs/myDevX2.yaml make all
   # or, for the whole session:
   export GENSYS_CONFIG=00_configs/myDevX2.yaml
   ```
2. **Unset, exactly one station yaml** in this folder or one level down in a
   per-station subfolder like `myDevX1/` (`TEMPLATE.yaml` aside) —
   auto-selected. This is why a single-station clone still works with no
   env var.
3. **Unset, several station yamls** — hard error listing them; set
   `GENSYS_CONFIG` and re-run. This is the guard against "forgot the env
   var, silently built this box as `myDevX1`".
4. **Unset, none** — warning; every `cfg` call falls back to its built-in
   default.

`load.sh` prints one `==> station config: ...` line per run so it's always
visible which station is being built.

## Which layers a station gets (`layers:` block)

The yaml doesn't just parameterize *how* layers apply — its `layers:` block
picks **which** layers `make all` (and the `CLAUDE_CONSUMER.md` build agent)
apply at all:

```yaml
layers:
  08_ai-agent-tools: "no"   # this station doesn't run the personal agent servers
  12_services: "no"         # ...or the soil cron / network-service states
```

Rules: `"no"` = skipped; omitted or `"yes"` = applied; **explicitly running
`make <layer>` bypasses the toggle** — naming a layer is the opt-in, same
convention as `14_udev`/`10_embedded-hw` (which are never part of `all` and
aren't listed here). See `TEMPLATE.yaml` for the full key list and the
caveats (`01_base` is the baseline everything else assumes; `04_storage: "no"`
also removes the default `/data/sysadmin` home — point
`station.sysadmin_dir` elsewhere). The template ships with
`08_ai-agent-tools`/`12_services` already `"no"` — a new station opts *in*
to the personal workloads, never inherits them.

## Onboarding a new station

1. `cp 00_configs/TEMPLATE.yaml 00_configs/<newStation>.yaml` (the filename
   is just a label, nothing parses it).
2. Fill in every `<...>` placeholder — the template comments say which
   command derives each one (`blkid`, `lspci`, `whoami`, …) — and review the
   `layers:` block. The personal layers (`08_ai-agent-tools`,
   `12_services`) are already `"no"`; if this station should take those
   workloads over, flip them to `"yes"` and uncomment + fill the matching
   `agents:`/`services:` section at the bottom of the template.
3. `export GENSYS_CONFIG=00_configs/<newStation>.yaml`, then walk the layers
   per the root `CLAUDE_CONSUMER.md` (agent-driven) or `make all` (scripted).
   (With two yamls now present, forgetting the export fails loudly instead
   of building the wrong station.)
4. Commit `00_configs/<newStation>.yaml` — it's the new station's own
   snapshot (like `myClean.yaml`). If it records personal layout you'd
   rather keep out of git, move it (and its optional companion files) into
   a per-station subfolder `00_configs/<newStation>/` and add that folder
   to the root `.gitignore` — the `myDevX1/` treatment — it then travels
   with the working-tree copy.
5. Optionally write the station's `host_<name>.md` end-state doc next to its
   yaml once the box is built (see `myDevX1/host_devX1.md` for the shape) —
   tracked or ignored, matching its yaml.
