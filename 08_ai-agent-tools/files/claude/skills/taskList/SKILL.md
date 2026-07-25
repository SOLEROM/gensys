---
name: my-task-list
description: On-demand multi-agent orchestration with one master, generic workers, and one QA gate. Trigger this skill when the user explicitly runs it by name or asks to orchestrate a task file through a master/worker/QA pipeline.
disable-model-invocation: true
---

# Master / Workers / QA

## Purpose

Use this skill when a task must be executed through:

- one **master** agent
- up to **max_workers** generic **workers**
- one **QA** agent
- exactly one authoritative **task file**

A task file is mandatory. This skill defines behavior only.

---

# CONFIG

```yaml
CONFIG:
  max_workers: 4
  max_depth: 3
  retry_limit: 3
  enable_log: false
  master_only_writes: true
  qa_checks_final_top_task_only: true
  allow_master_create_new_top_tasks: true
  allow_workers_propose_subtasks: true
  allow_task_reorder: true
  allow_task_rename: true
  allow_dependency_edit: true
  allow_merge_split: true
  scheduling_policy: dependency_ready_then_file_order
  require_explicit_task_file: true
  require_existing_task_file: true
  require_valid_task_file: true
```

---

# Bundled Resources

This skill folder may contain the following resource files. Check for their presence at startup and load them as described:

| File | When to load |
|---|---|
| `task-template.md` | Load when initializing a new task file from scratch or when the user has no existing managed file |
| `task-normalize-template.md` | Load before normalizing any raw input file — use as the canonical format reference |

If either file is missing, fall back to the inline format definitions in this document.

---

# Core Invariants

1. There is exactly one authoritative task file.
2. The user supplies the initial file.
3. The master validates it, then rewrites that same file in place into managed format.
4. Optional backups are allowed, but backups are never authoritative.
5. Only the master may write the task file.
6. Workers never write the task file directly.
7. QA only decides final success or final failure.
8. If any task fails `retry_limit` times, the whole run fails.
9. The master must publish a final status tree and summary.

---

# Required Input

The required starting syntax is minimal plain Markdown:

```
[] first task
[] second task
[] third task
```

The master may normalize that file by:

* adding IDs
* adding metadata
* clarifying wording
* fixing typos and grammar
* rewriting vague tasks into clearer executable descriptions
* adding dependencies
* splitting tasks into subtasks
* reordering tasks
* creating new top-level tasks if needed

The master must preserve the original intent. If `task-normalize-template.md` is present, use it as the format reference for normalization.

---

# Managed States

Allowed task states:

* `[]` not started
* `[/]` in progress
* `[>]` expanded into subtasks
* `[v]` completed
* `[x]` terminal failure

Rules:

* `[]` means present but not active
* `[/]` means assigned and active
* `[>]` means parent task with children
* `[v]` means complete from master perspective
* `[x]` means permanently failed

Do not mark intermediate failed attempts as `[x]` until retry limit is reached.

---

# Roles

## Master

The master must:

* validate the input file
* normalize the file into managed format (using `task-normalize-template.md` if present)
* keep that same file as the only source of truth
* assign task IDs
* improve wording where needed
* manage dependencies and conflicts
* assign work to workers
* accept or reject proposed task changes
* track retries and failure notes
* retry failed tasks with another worker when possible
* stop the run when retry limit is reached
* send the final top task to QA
* publish the final status tree and summary

## Workers

Workers must:

* work only on assigned tasks
* never edit the task file directly
* self-check before returning results
* report completion or failure by returning a structured result (see **Worker Result Format**)
* propose subtasks when a task needs decomposition
* never declare final success or failure

## QA

QA must:

* review only the final top-level objective
* approve only if the actual goal is satisfied
* reject unsupported completion claims
* explain what is still wrong or missing
* reopen the top task through master-controlled update flow
* be the only authority for final success or final failure

---

# Worker Result Format

When a worker finishes an assigned task, it must return a structured result to the master. The master uses this to update the task file.

```
WORKER RESULT
task_id: T001
status: completed | failed | blocked | decompose
output: <brief description of what was done or produced>
proposed_subtasks:        # only when status is decompose
  - T001.1: <description>
  - T001.2: <description>
failure_reason:           # only when status is failed or blocked
  <what went wrong>
```

The master reads this result and applies the appropriate update to the task file. Workers never touch the file directly.

---

# Status Tree

After every meaningful state change, and always at the end of a run, the master must render a status tree to the console. This gives a live view of the entire task hierarchy and its current state.

## Format

```
[status] [ID] Task title
    [status] [ID.1] Subtask title
        [status] [ID.1.1] Deeper subtask
    [status] [ID.2] Subtask title
```

## Legend line (always include below the tree)

```
Legend: [] not started  [/] in progress  [>] has subtasks  [v] done  [x] failed
```

## Example

```
[v] [T001] Set up project scaffold
    [v] [T001.1] Create directory structure
    [v] [T001.2] Initialize config files
[/] [T002] Implement parser
    [v] [T002.1] Define grammar rules
    [/] [T002.2] Write tokenizer
    [] [T002.3] Write AST builder
[] [T003] Write tests
[x] [T004] Deploy to staging  ← failed after 3 attempts

Legend: [] not started  [/] in progress  [>] has subtasks  [v] done  [x] failed
```

The tree must reflect the exact current state of the task file at the time it is rendered.

---

# Logging (enable_log)

## enable_log: false (default)

The master operates silently except for:
- the status tree after each batch of updates
- worker result summaries
- the final report

## enable_log: true

When logging is enabled, the master narrates every stage it takes, both to the console and into the final report. Each log entry should be prefixed with a stage label.

Stages to narrate:

| Stage label | When to emit |
|---|---|
| `[VALIDATE]` | Checking the task file for validity |
| `[NORMALIZE]` | Rewriting the file into managed format |
| `[SCHEDULE]` | Selecting the next batch of tasks to assign |
| `[ASSIGN]` | Sending a task to a worker |
| `[WORKER RESULT]` | Receiving and processing a worker result |
| `[RETRY]` | Retrying a failed task |
| `[DECOMPOSE]` | Splitting a task into subtasks |
| `[QA]` | Sending to QA and receiving verdict |
| `[QA REJECT]` | Reopening a task after QA rejection |
| `[FAIL]` | A task has reached retry limit |
| `[COMPLETE]` | All tasks done, QA approved |

Example verbose output:

```
[VALIDATE] Task file found at tasks.md. 3 raw tasks detected.
[NORMALIZE] Rewriting into managed format using task-normalize-template.md.
[SCHEDULE] Dependency-ready tasks: T001, T002. Assigning up to 4 workers.
[ASSIGN] T001 → Worker 1
[ASSIGN] T002 → Worker 2
[WORKER RESULT] T001 completed. Output: directory structure created.
[WORKER RESULT] T002 failed. Reason: missing dependency on T001.
[RETRY] T002 reassigned to Worker 3. Attempt 2/3.
```

When `enable_log: true`, the final report must include the full stage log as an appended section.

---

# Task IDs and Metadata

The master assigns explicit IDs:

* top-level: `T001`, `T002`
* subtasks: `T001.1`, `T001.2`
* deeper: `T001.2.1`

Example managed entry:

```md
[] [T001] Build parser
    tries: 0
    depends:
    notes:
```

Recommended fields:

* `tries`
* `depends`
* `notes`

Optional fields:

* `owner`
* `last_fail`

If `task-template.md` is present, use it as the canonical structure for new task entries.

---

# Single-File Safety

To avoid race conditions:

* only the master writes the file
* workers only propose updates via the Worker Result Format
* QA feedback is written through the master
* no shadow task file is used
* no worker-local plan is authoritative

The user-supplied file is rewritten in place and remains the only live task file for the run.

---

# Scheduling Rules

The master uses:

1. find dependency-ready tasks
2. remove blocked or conflicting tasks
3. choose tasks in top-to-bottom file order
4. assign up to `max_workers`

A task is runnable only if:

* it is `[]`
* all dependencies are `[v]`
* it is not already assigned
* it does not conflict with active work
* it does not violate parent-child rules

If a task has active child tasks, the parent must be `[>]`.

---

# Decomposition Rules

A worker may decide a task must be split.

Flow:

1. worker receives task
2. worker returns result with `status: decompose` and `proposed_subtasks`
3. master validates the proposal
4. master updates the file
5. parent becomes `[>]`
6. child tasks are inserted
7. original assignment ends
8. master later schedules the children

Decomposition must not exceed `max_depth`.

---

# Retry and Failure Policy

On each failed attempt:

1. master increments `tries`
2. master records failure details in notes
3. master returns the task to `[]` unless retry limit is reached
4. retry should go to another worker when possible

If any task reaches `retry_limit` and still fails:

* master marks it as terminal failure candidate
* the run moves toward failure
* QA confirms final failure
* after QA confirms, the run is failed

One task failing 3 times fails the whole run.

---

# Completion Policy

Final success requires all of the following:

* no unresolved required work
* no active `[/]` tasks
* no blocking `[]` tasks
* no terminal failure
* QA approval of the final top task

If QA rejects:

* master reopens the top task to `[]`
* master updates notes with the rejection reason
* orchestration continues

Workers and master may believe work is done, but only QA can finalize the result.

---

# Final Report

At the end of every run, the master must publish:

1. **Status tree** — full task hierarchy with final states (see Status Tree section)
2. **Overall result** — `SUCCESS` or `FAILURE`
3. **Summary table**:

| Category | Count |
|---|---|
| Completed | N |
| Failed (terminal) | N |
| Not started | N |
| Total retries | N |

4. **QA verdict** — approved or rejected, with reason if rejected
5. **Failed task details** — for each `[x]` task: ID, title, failure reason, number of attempts

If `enable_log: true`, append the full stage log after the summary.

---

# Refusal Conditions

Refuse to start if:

* no task file is supplied
* the file does not exist
* the file contains no valid `[]` task entries
* the file is too malformed to normalize safely
* execution would require more than one authoritative task file

---

# Operating Procedure

1. Validate explicit task file path.
2. Validate file exists.
3. Validate at least one raw `[]` task exists.
4. Check for `task-normalize-template.md` and `task-template.md` in skill folder; load if present.
5. Normalize the file in place (using template if available).
6. Assign IDs and metadata.
7. Clarify wording and fix typos if needed.
8. Render initial status tree.
9. Schedule dependency-ready tasks.
10. Collect worker results via Worker Result Format.
11. Render updated status tree after each batch.
12. Apply approved updates through the master only.
13. Retry failed tasks until success or retry limit.
14. Send final top task to QA.
15. If QA rejects, reopen and continue from step 9.
16. If QA approves, finish successfully.
17. If retry limit is exceeded, fail the run.
18. Publish final report (status tree + summary + log if enabled).
