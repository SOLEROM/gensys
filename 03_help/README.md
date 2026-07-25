# 03_help/ — console help pages behind the `h`/`hh`/`h.*` aliases

Not a numbered layer — like `02_aliases/`, this is cross-cutting content that
`05_shell` installs. These are the plain-text cheat-sheet pages the help
aliases in `02_aliases/alias.bashrc` print:

| alias | does |
|---|---|
| `h` | `cat $helpRoot/welcome` — the index page |
| `hh` | `cd $helpRoot; ls` — list all pages |
| `h.alias` | full alias/jump-shortcut list |
| `h.keys` | key shortcuts — i3/Regolith custom + stock, shell helpers |
| `h.git` | git recipes + the repo aliases (`gitup`, `git.sol`, …) |
| `h.docker` | Docker CE on this box: data-root, cleanup, compose templates |
| `h.wifi` | nmcli (default) + bare wpa_supplicant fallback |
| `h.pdf` | ghostscript/pdftoppm tricks |
| `h.code` | VS Code/Cursor notes + extension dump/restore |
| `h.dev` | dev runtimes: `uv`/`pyenv`/nvm/rustup/java/jupyter (07_dev) |
| `h.find` | locate/rg/fdfind/ag/fzf/batcat/ncdu (01_base search set) |
| `h.ai` | Claude Code, usage monitors, agent servers, ollama (08_ai-agent-tools) |
| `h.ts` (`h.tailscale`) | tailnet daily use, join, ACLs (11_tailscale) |
| `h.services` | systemd units, network-service states, cron, syncthing (12_services) |
| `h.gensys` | how to rebuild/extend the box from this repo itself |

`$helpRoot` is `<sysadmin_dir>/help`, derived from `sys` in `alias.bashrc`
(`station.sysadmin_dir` in the station config; default `/data/sysadmin`).
`05_shell/apply.sh` copies `welcome` + `h_*` from here to that path (glob —
new `h_*` files are picked up with no apply.sh change) — this README stays
repo-only.

## Editing

Each page is a plain-text note printed to the terminal — no markdown
rendering, keep lines short and tab-aligned. Add a new topic by dropping an
`h_<topic>` file here, listing it in `welcome`, and adding a matching
`h.<topic>` alias in `02_aliases/alias.bashrc`'s help section. Edit pages in
the repo and re-apply (`make 05_shell`), not in `$helpRoot` — the next
apply overwrites the installed copies.

## Origin

Mined from `/data/sysadmin/ubu20/02_help` (the old-station lineage), then
**rewritten 2026-07-24 against the gensys layer set** so every page matches
what the layers actually install on a fresh ubu24 host:

- `welcome`, `h_alias`, `h_keys` — refreshed to the full merged
  `02_aliases/alias.bashrc` set and the `06_desktop-i3` custom keybindings.
- `h_docker` — rewritten for the Docker CE + relocated data-root install
  (`09_docker`); the old snap-docker section dropped (obsolete on a
  gensys-built box).
- `h_git`, `h_wifi`, `h_pdf`, `h_code` — old recipes kept, extended with
  the aliases/tools the layers now provide (nmcli, extension lists, …).
- `h_dev`, `h_find`, `h_ai`, `h_tailscale`, `h_services`, `h_gensys` — new
  pages, one per big theme of the rebuilt toolset (`07_dev`, `01_base`
  search tools, `08_ai-agent-tools`, `11_tailscale`, `12_services`, and
  the repo itself).
