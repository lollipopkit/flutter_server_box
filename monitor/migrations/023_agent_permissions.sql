-- Agent mode's permissions (`agent_mode/permissions.rs`): how the commands a
-- task runs are approved. One row, set by an admin; absent is `manual` with
-- no rules and the built-in auto mode rules.
--
-- Text times are RFC 3339, bound by the writer (see migration 012).

CREATE TABLE agent_permissions (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    -- The mode a new task starts in unless its account picks another:
    -- `manual`: what no rule or known read settles is asked; `auto`: a model
    -- judges it against `auto_mode`; `bypass`: it runs.
    default_mode TEXT NOT NULL CHECK (default_mode IN ('manual', 'auto', 'bypass')),
    -- 1: no task runs in `bypass` (one that was started in it runs `manual`).
    disable_bypass INTEGER NOT NULL DEFAULT 0 CHECK (disable_bypass IN (0, 1)),
    -- JSON `{"allow": [...], "ask": [...], "deny": [...]}` of command
    -- patterns (`sbm_parser::command_rules`).
    rules TEXT NOT NULL DEFAULT '{}',
    -- JSON `{"environment"?, "allow"?, "soft_deny"?, "hard_deny"?}`: prose
    -- lists for the auto mode judge; absent is the built-in list, `$defaults`
    -- in one splices the built-in list there.
    auto_mode TEXT NOT NULL DEFAULT '{}',
    updated_at TEXT NOT NULL
);

-- The mode each task runs in, picked when it was started.
ALTER TABLE agent_flow ADD COLUMN mode TEXT NOT NULL DEFAULT 'manual' CHECK (mode IN ('manual', 'auto', 'bypass'));
