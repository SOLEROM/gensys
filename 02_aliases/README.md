# 02_aliases/ — one combined alias/function source, repo-owned

Not a numbered layer — this is cross-cutting infrastructure that `05_shell`
(and a couple of other layers/scripts) points at, per owner decision: one
canonical alias file instead of splitting aliases across layers by topic or
debating between two host conventions.

## What's here

```
02_aliases/
  alias.bashrc        # the ONE combined alias/function source (bash+zsh, shell arg like before)
  bashrc_colors        # prompt color definitions alias.bashrc sources
  scripts/
    tit.sh  titZSH.sh  wrsp_name.sh  wrsp_addNewNamed.sh   # terminal-title / i3-workspace-rename+create helpers
    multiScreen/   # scrLay0/1/2.sh + thisName.sh: move i3 workspaces to a named physical monitor output
    gitScripts/   # multi-repo git helpers (statusOnAll, orphan-md finder, tree w/ .gitignore,
                  #   git-brief.sh + git-brief.prompt.md: claude-written commit msg for ./)
    tmux/lisTree.sh
    maps/mapls.sh
    shell/setStaticIPbyUUID.sh
```

Consumed by `05_shell/README.md`'s Apply step (renders/copies everything
here to `<sysadmin_dir>/00_bashrc/` and `<sysadmin_dir>/01_scripts/...`,
where `<sysadmin_dir>` is `station.sysadmin_dir` from the station config —
default `/data/sysadmin`). The help pages the `h`/`hh`/`h.*` aliases
print live in the sibling top-level `../03_help/` folder (installed by
`05_shell` to `<sysadmin_dir>/help/` — see `03_help/README.md`).
Three `{{PLACEHOLDER}}` families get rendered by `05_shell/apply.sh` at
copy time (never hand-edited):
- `{{GENSYS_REPO_ROOT}}` — `alias.bashrc`'s `secrets/hosts.env` sourcing and
  `git.solerom`/`git.trip` ssh-add paths; substituted with this repo
  clone's real location, computed live by `00_configs/load.sh`.
- `{{SYSADMIN_DIR}}` — `alias.bashrc`'s `$sys` root; substituted from
  `station.sysadmin_dir` so a station can keep the vendored scripts
  anywhere by editing one config value.
- `{{MON_LAPTOP}}/{{MON_WIDE}}/{{MON_TOP}}` — `scripts/multiScreen/scrLay*.sh`
  monitor output names; substituted from `desktop.monitors.*`.

## General vs. host-specific

`alias.bashrc` only holds aliases/functions that make sense on **any**
station this repo builds — nothing that names a project directory, port, or
peripheral that only exists on one particular box. Anything tied to one
station's personal layout (its agent-server dirs, its project checkouts
under `/data`, which USB port a serial device landed on, …) lives instead in
that station's **`00_configs/<station>_aliases`** companion file (e.g.
`00_configs/myDevX1/myDevX1_aliases`) — same git-ignored, working-tree-only
treatment as `<station>.yaml` and `host_<station>.md` (see
`00_configs/README.md`'s "Separation contract"). That file depends on vars
`alias.bashrc` sets (`$sys`, `$data`, `$proj`, `$tasks_script`) so it must be
sourced after it. Wired since 2026-07-25: `05_shell/apply.sh` installs the
active station's companion (rendered, same tokens as `alias.bashrc`) to the
fixed path `<sysadmin_dir>/00_bashrc/station_aliases`, and `alias.bashrc`'s
**last** block sources that path if present — both shells, silently skipped
on stations without a companion, stale copies removed on re-run.

## Merge rules applied

This file merges **two prior lineages**: this repo's own earlier
`05_shell/files/alias.bashrc` capture, and this host's
`/data/sysadmin/00_bashrc/solov.bashrc`. Rules used:

- Keep the generically useful stuff from both, all in **one file**, no more
  splitting by topic: `gitup()`, `gitall`, `gitstat`, `nn` (nnn wrapper),
  `topmem`, `img`, `publicIP`, `obsidian` launcher, `keySetEng`/`keySetHeb`
  (bilingual input-source toggle), `stip` (static-IP-by-UUID), Docker helpers
  (`dok_ps`, `dok_ls`, `d.killall`), AI-agent control aliases (`cld_mon`,
  `clw_start`/`stop`, `oll_start`/`stop`).
- Dropped dead blocks entirely (not carried anywhere): `mypass` (referenced
  a stale `/home/solov/...` path under a different, legacy username), the
  commented `theKernel`/`wifiDev` relics. `git.fll`/`fllKey` (unrelated
  kids'-robotics side project — see `../secrets/README.md`) is real but
  myDevX1-only, so it now lives in `00_configs/myDevX1/myDevX1_aliases` instead of
  here (see "General vs. host-specific" above), not dropped outright.
- `nn` simplified to a plain `nnn` call — the old alias pointed at a
  `ubu18`-era custom build (`07nnn/nnnFromSrc`) that no longer matters now
  that `01_base` apt-installs `nnn` (along with `cscope` for `vv` and `eog`
  for `ee`/`img`).
- **No secrets in this file.** Every place the old files had a literal
  password (`sshpass -p <cleartext>`) now references an env var instead
  (`$VPS1_PASS`, `$TAB1_PASS`, …), sourced from `secrets/hosts.env` if
  present, silently skipped if not — see `../secrets/README.md` (key-name
  template: `secrets/hosts.env.example`, git-ignored alongside the real
  file). The same
  source-if-present block also loads `secrets/api-keys/GPT_API` (an env
  file exporting `OPENAI_API_KEY` for `claude-monitor` & co).
- **GitLab support removed 2026-07-24** (owner decision — the old local
  LAN instance is obsolete): `gitScripts/newGitlabRepoCreate.sh`
  deleted, the `lab.new` alias dropped, `GITLAB_*` env vars and the
  `network.gitlab_*` config keys removed.
- `.xbindkeysrc` / `.xmodmap-<host>` (legacy X11-level keybindings/keymap
  from before i3 `config.d` existed) — **not** folded in here; still an open
  question whether they're worth carrying at all now that Regolith/i3 covers
  keybindings.
- **Bug found and fixed 2026-07-24**: the merged `pp` alias pointed at
  `$bashScripts/ppTask/taskit0.sh` — a **dead reference**, that path never
  existed on this host (confirmed via `find`), evidently a stale relic from
  an even older lineage than the two this file merges. The owner flagged
  `pp` specifically as "a tool I want on every next station," which is what
  caught it. Fixed to match what's actually live today: `pp` now runs
  `/proj/myGits/syso/stacker/taskStack/demo1.sh` (an `fzf`-based
  multi-project task runner — code lives on `/data`/`/proj`, survives the
  reinstall via `04_storage` same as the `08_ai-agent-tools` personal
  servers, nothing to vendor here) against `/data/.taskit.projects` (also
  on `/data`, survives as-is). Depends on `fzf` (already in `01_base`).
  Three sibling aliases (`todo`, `tt`, `robo`/`rob`) were found alongside
  `pp` in the live bashrc. Resolved 2026-07-25: `robo`/`rob` (target
  `/data/proj/robo/_MENU` exists) moved to `00_configs/myDevX1/myDevX1_aliases` as
  myDevX1-specific; `todo`/`tt` stayed out because their target
  (`/data/todo`) doesn't exist on this host at all — nothing to point them
  at yet.

## Origin

- `alias.bashrc`, `bashrc_colors`: merged from this repo's prior
  `05_shell/files/{alias.bashrc,bashrc_colors}` and
  `/data/sysadmin/00_bashrc/solov.bashrc`.
- `scripts/{tit.sh,titZSH.sh,wrsp_name.sh}`: carried over unchanged from this
  repo's prior `05_shell/files/scripts/`.
- `scripts/gitScripts/*`, `scripts/tmux/lisTree.sh`, `scripts/maps/mapls.sh`,
  `scripts/shell/setStaticIPbyUUID.sh`: mined from
  `/data/sysadmin/ubu20/01_scripts/{gitScripts,maps,shell}/` and
  `/data/sysadmin/ubu24/01_scripts/tmux/lisTree.sh` — the last living copies
  before `/data/sysadmin` is retired.
- `scripts/wrsp_addNewNamed.sh`, `scripts/multiScreen/*`: migrated in
  2026-07-24 from `/data/sysadmin/ubu24/02_i3Reg/scripts/{wrkspNames,
  multiScreen}/` — found missing during a follow-up audit of `ubu24`
  against this repo (its sibling `wrsp_changeCurName.sh` had already been
  carried over as `wrsp_name.sh`, but `wrsp_addNewNamed.sh` and the whole
  `multiScreen/` folder had not). Wired to `newname`/`i3-newname` in
  `alias.bashrc`, mirroring the existing `name`/`i3-name` pattern. The
  `multiScreen/` scripts' monitor names are **machine-specific** and since
  2026-07-24 are `{{MON_LAPTOP}}/{{MON_WIDE}}/{{MON_TOP}}` templates,
  rendered by `05_shell/apply.sh` from the station config's
  `desktop.monitors.*` (fill those in from `xrandr --listmonitors` on the
  target box).
