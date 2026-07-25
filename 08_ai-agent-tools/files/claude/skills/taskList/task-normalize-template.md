# CONFIG
max_workers: 4
max_depth: 3
retry_limit: 3
enable_log: false
master_only_writes: true
qa_checks_final_top_task_only: true

# TASKS
[>] [T001] Build CLI tool
    tries: 0
    depends:
    notes: normalized from raw task text

  [>] [T001.1] Implement core CLI deliverable
      tries: 0
      depends:
      notes: parent task expanded into subtasks

    [] [T001.1.1] Create project structure
        tries: 0
        depends:
        notes:

    [] [T001.1.2] Add command entrypoint
        tries: 0
        depends: T001.1.1
        notes:

    [] [T001.1.3] Add argument handling
        tries: 0
        depends: T001.1.2
        notes:

[] [T002] Add configuration parser
    tries: 0
    depends: T001.1.1
    notes: wording clarified from raw input

[] [T003] Write tests
    tries: 0
    depends: T001.1.2, T002
    notes:

[] [T004] Write README
    tries: 0
    depends: T001.1.2
    notes:

# FINAL_TOP_TASK
[] [TOP] Deliver complete CLI tool
    tries: 0
    depends: T001, T002, T003, T004
    notes: QA checks only this final top task