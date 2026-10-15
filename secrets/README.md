# secrets/ — git-ignored transfer staging, never committed

**Everything in this folder except this README is excluded by the repo's
`.gitignore`** (`/secrets/*` + `!/secrets/README.md`). This is where
credentials that must move host-to-host get staged for manual transfer
(encrypted USB, `scp` over the existing Tailscale net, a password manager) —
it is **not** a mechanism for a fresh host to auto-provision itself from git,
since none of this ever reaches git.

## Layout

| Path | Contents |
|---|---|
| `hosts.env` | `VPS1_*`, `TAB1_*`, `SSHLP_*`, `VOXL_PASS`, `GITLAB_*` — sourced by `aliases/alias.bashrc` and `aliases/scripts/gitScripts/newGitlabRepoCreate.sh` if present, silently skipped if not |
| `cameras/soil.env` | `TAPO_USER`/`TAPO_PASS` for the soil-monitoring cron pipeline — sourced by `/proj/soil/soliAnal1.sh` |
| `ssh/` | Private keys: `gitKey_private_github` (+ `.pub`), `tripRepo_` (+ `.pub`), `hIT_id_rsa` (+ `.pub`), `github-recovery-codes.txt` |
| `api-keys/` | `GPT_API` (OpenAI key, used by `claude-monitor`/misc tooling) |

## Restore on the new host

```bash
mkdir -p ~/.ssh
cp secrets/ssh/gitKey_private_github ~/.ssh/   && chmod 600 ~/.ssh/gitKey_private_github
cp secrets/ssh/tripRepo_             ~/.ssh/   && chmod 600 ~/.ssh/tripRepo_
cp secrets/ssh/hIT_id_rsa            ~/.ssh/   && chmod 600 ~/.ssh/hIT_id_rsa
ssh-add ~/.ssh/gitKey_private_github ~/.ssh/tripRepo_ ~/.ssh/hIT_id_rsa
```

`hosts.env` and `cameras/soil.env` just need to land back at these same
relative paths under wherever this repo is cloned — nothing else to do,
the alias/cron scripts `source` them conditionally.

## Rotation — do before/at time of transfer, not after

- **`VPS1_PASS` (VPS root password)** — was sitting in cleartext in
  `/data/sysadmin/00_bashrc/solov.bashrc` for an unknown amount of time
  before this move. Rotate it on the VPS itself; moving it here doesn't
  undo that prior exposure.
- **`TAB1_PASS`, `SSHLP_PASS`** — same "was cleartext in a dotfile"
  reasoning, lower blast radius (local LAN devices, not internet-facing).
- **`TAPO_PASS` (soil camera)** — trivial to rotate via the Tapo app; low
  stakes (LAN-only camera) but cheap to fix.
- **`GITLAB_API_TOKEN`** — local GitLab instance (`192.168.2.3`), regenerate
  from its web UI; also LAN-only.
- **`VOXL_PASS`** — not actually secret; `oelinux123` is that dev-board
  family's well-known default OE-Linux password, kept here only for the
  one-source-of-secrets convention, not because it's sensitive.

> **Note on this session specifically**: while building this folder, two
> debug commands meant to *verify* extraction instead printed the VPS/tab1/
> sshlp passwords and the Tapo camera password in plaintext into this
> conversation's tool output, before the redaction bugs were caught and
> fixed. Treat all four as burned regardless of how low-stakes some of them
> are — rotate them, don't just relocate them.

## Dropped, not migrated (reviewed, decided not worth carrying forward)

- `/data/sysadmin/srvGIts/erez20/cred/octoprint` — a third party's (Erez's)
  OctoPrint credential for their own 3D printer; unrelated to this station,
  not moved. Revisit only if that integration turns out to still matter.
- `/data/fll/.keys/fllKey` (+ the `git.fll` alias that used it) — a
  kids'/FLL-robotics side project's deploy key, unrelated to the dev-station
  rebuild this repo targets. Already persists via `/data/fll` on the reused
  disk regardless; not part of `gensys`.
- `alias.bashrc`'s `git.lab` referenced `$sys/10_gitKeys/gitKey_private_gitlab`
  — no such file was found on this host (dead reference, likely stale from
  an earlier setup). Not fabricated; dropped from the merged alias file.

## `~/.aws/`

Left alone — standard AWS CLI convention, not this repo's concern. Re-run
`aws configure` or restore from your own password manager on the new host.
