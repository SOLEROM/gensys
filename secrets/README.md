# secrets/ — git-ignored transfer staging, never committed

**Everything under `secrets/` except this README is excluded by the repo's
`.gitignore`** (`/secrets/*` with a single `!/secrets/README.md` exception).
Credentials that must move host-to-host — env files holding passwords or
API tokens, private SSH keys — are staged here for **manual** transfer:
encrypted USB, `scp` over an already-trusted link, a password manager.
This is *not* a mechanism for a fresh host to auto-provision itself from
git — nothing in this folder ever reaches git, so a plain `git clone`
contains only this file.

## Conventions

- **Sourced conditionally.** Consumers elsewhere in the repo (shell
  aliases, cron scripts) `source` a file from here *if it exists* and
  silently skip it otherwise — every layer applies cleanly with this
  folder empty; the matching features just stay dormant until the file
  is restored.
- **`.example` templates.** Each real env file has a matching `*.example`
  beside it (key names and usage comments, no values) to refill from if
  the real file was lost rather than transferred. The templates are
  git-ignored too — they travel only with the working-tree copy, like
  everything else here.
- **Same relative paths.** Restoring on a new host means landing the files
  back at the same paths under wherever this repo is cloned. SSH keys are
  consumed **in place** from `secrets/ssh/` (the `ssh-add` aliases in
  `02_aliases/alias.bashrc` point straight at them — nothing copies them to
  `~/.ssh`); keep them `600`. Only copy a key into `~/.ssh` if some tool
  demands it, with the same `600` permissions.
- **Rotate on transfer.** Any credential that ever sat in cleartext
  somewhere less controlled than this folder is rotated at transfer time,
  not merely relocated.

## Station-specific inventory

The actual per-station details — which credential files exist, what
consumes each one, exact restore commands, and rotation status — live in
**`myReadme.md`** in this same folder. That file is git-ignored on purpose
(it names real hosts, keys, and accounts) and travels with the manual copy
of the working tree, alongside the secrets it documents.
