

# GenSys - aiops install ubu24.

Layered instructions for rebuilding the owner's Ubuntu 24.04 desktop on a
**fresh** machine. Each numbered layer `NN_name/` is self-contained: a
`README.md` (the instruction), a `files/` dir of verbatim snapshots, and an
`apply.sh` that executes the README. This repo describes the target system —
it is not a one-shot installer, and authoring it changes nothing on the
current machine.

## Build a fresh machine

```bash
./install.sh   # bootstraps make + claude, then hands off
```

Two paths from there:

- **Agent-driven** (recommended): a Claude Code session
  (`claude --dangerously-skip-permissions` — deps pre-seeds sudo permission)
  follows [`CLAUDE_CONSUMER.md`](./CLAUDE_CONSUMER.md) — probes hardware, asks
  the few required choices, gates out layers the box doesn't need, applies,
  verifies.
- **Scripted**: `make all` — same layers, no agent in the loop.
  `make list` prints every rule; `make <layer>` runs one layer.

Machine-specific values (UUIDs, ports, paths, …) come from that station's
`00_configs/<name>.yaml`; a new station starts by copying
`00_configs/TEMPLATE.yaml` — see [`00_configs/README.md`](./00_configs/README.md).

