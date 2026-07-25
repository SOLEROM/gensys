# CLAUDE.md — session routing for this repo

This repo (`gensys`) is a layered set of instructions for rebuilding the
owner's Ubuntu 24.04 / Regolith-i3 environment on a **fresh** machine.
A Claude Code session here is in one of two modes — decide which before
doing anything:

1. **Provisioning a new host** (the owner says "install", "build this box",
   "start the build", or you're clearly on a freshly installed machine):
   read [`CLAUDE_CONSUMER.md`](./CLAUDE_CONSUMER.md) and follow it — it
   defines the build-agent role (probe → ask → gate → apply → verify).
   Do not start applying layers without going through it.

2. **Maintenance mode** (everything else — the default): you are on the
   author's working machine, editing layers, snapshots, and docs.
   **Authoring changes nothing on the current system** — never run a
   layer's `apply.sh` or `make <layer>` against this machine unless the
   owner explicitly asks.

Maintenance conventions (details in [`README.md`](./README.md)):

- Each layer `NN_name/` has a `README.md` with fixed sections
  (Purpose → Prerequisites → Files → Apply → Verify → Machine-specific
  values → Origin), a `files/` dir of verbatim snapshots mirroring target
  paths, and an `apply.sh` that is the README's literal execution.
- Machine-specific values live in `00_configs/<station>.yaml`, read via
  `00_configs/load.sh` (`cfg`, `render_template`); env vars override.
  `{{PLACEHOLDER}}` tokens appear only in files that can't shell-expand.
- `secrets/`, the per-station folder `00_configs/myDevX1/` (config yaml,
  end-state doc, host aliases), and `15_firefox/bookmarks/` are git-ignored
  by design — they travel as working-tree copies, never as commits.
- `10_embedded-hw`, `14_udev`, and `16_vps` are reference/on-demand only:
  not in `make all`, never applied or asked about by default.
