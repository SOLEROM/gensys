# 09_docker — Docker CE + parameterized data-root + image/compose BOM

## Purpose

Docker engine, moved off the OS disk's default `/var/lib/docker` to a
chosen location — a **parameter**, not a hardcoded path, because "the right
drive" genuinely differs per host/run. This host currently has three
storage devices (`/`, `/data`, and an external backup drive), and
its live `docker info` shows the real current root is `/data/dockerDATA` —
not `~/proj/docker`, which is what the pre-existing draft script
(`/data/sysadmin/ubu24/04_dockers/installAndConf.sh`) hardcoded, and which
doesn't even exist on this host. The fix isn't picking the one right path
for this one host — it's not hardcoding it at all.

---

## Prerequisites

`04_storage` applied first (`$DOCKER_DATA_ROOT` almost always lives under
`/data`, which needs to be mounted before this layer moves anything onto
it).

---

## Files in this layer

| repo path | target on fresh box |
|---|---|
| `apply.sh` | the layer entry point — resolves `DOCKER_DATA_ROOT` (env → `docker.data_root` → default) and runs the script below |
| `files/installAndConf.sh` | run via `apply.sh` (not copied anywhere permanent) — installs Docker CE + relocates data-root |

---

## Apply

```bash
./apply.sh          # reads docker.data_root from the station yaml
# one-off override, same as the Makefile path:
DOCKER_DATA_ROOT=/mnt/bkData/docker ./apply.sh
```

(Running `files/installAndConf.sh` directly skips the station-config lookup
— it then falls back to the literal `/data/dockerDATA` default.)

`CLAUDE_CONSUMER.md` Step 2 (owner questions) includes: *"Where should
Docker's image/container storage live? (default: `/data/dockerDATA`)"* —
same treatment as the wallpaper question. The Makefile path takes it as
`DOCKER_DATA_ROOT=/path make 09_docker`, same default if unset.

### Images/containers — bill of materials, not snapshots

Reproducible via `docker pull`/`compose`, not backed up as data:
`ollama/ollama`, `qdrant/qdrant`, `postgres:15-alpine`, `redis:7-alpine`,
`caddy:2-alpine`, `discourse/base`, `portainer-ce`, `mailhog`, plus
project-local `garage-local-*`/`cldimg-*` images. Compose files already live
on `/data`/`/proj` (survive via `04_storage`) — just note their paths here,
don't copy them into this repo:

- **Reusable compose templates**: `/data/proj/myGits/forge/composers/` — 8
  generic patterns (reproducible workspace, tool-split, multi-service
  pipeline, hardware-aware runtime, environment profile, stateful service,
  disposable task, observability sidecar). This directly answers "what
  template docker should I rebuild" — this layer's job is just getting
  Docker running and pointed at it, not vendoring the templates themselves.

---

## Verify

```bash
sudo docker info | grep "Docker Root Dir"   # matches $DOCKER_DATA_ROOT
sudo docker buildx version
sudo docker run --rm hello-world
groups | grep docker                   # sudo-less docker only after re-login
ls /data/proj/myGits/forge/composers/  # compose templates (via /proj only
                                       # after the optional bind mount —
                                       # see 04_storage/README.md)
```

---

## Machine-specific values

- **`DOCKER_DATA_ROOT`** — default now sourced from `docker.data_root` in
  the active station's `00_configs` yaml (`/data/dockerDATA` default), overridable
  to any mounted path (root fs, the external `bkData` drive, or a different
  drive entirely on a future host) via the env var, same as before this
  existed. Asked once, not guessed.

---

## Origin

Adapted from `/data/sysadmin/ubu24/04_dockers/installAndConf.sh` (already
tested on this host) — the data-root hardcode replaced with the
`DOCKER_DATA_ROOT` parameter; everything else unchanged. Image/compose list
and `docker info` captured 2026-07-23.
