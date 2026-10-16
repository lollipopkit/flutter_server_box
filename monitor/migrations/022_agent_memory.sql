-- Agent mode's memory (`agent_mode`): an account's text files under
-- `/memories`, which the agent reads and writes across that account's tasks
-- with the `memory_*` tools, the files the apps keep their memory in. `path`
-- is the key below `/memories` (`MEMORY.md`, `projects/app.md`).
--
-- Text times are RFC 3339, bound by the writer (see migration 012).

CREATE TABLE agent_memory (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    content TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (user_id, path)
);
