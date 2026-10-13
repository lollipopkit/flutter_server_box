-- MCP servers an admin added for Agent mode (`agent_mode::mcp`): Streamable
-- HTTP, and the headers sent with every request (a token, most often), a JSON
-- object of name to value that is never read back out.
CREATE TABLE agent_mcp_server (
    id TEXT PRIMARY KEY,
    position INTEGER NOT NULL,
    name TEXT NOT NULL,
    url TEXT NOT NULL UNIQUE,
    enabled INTEGER NOT NULL DEFAULT 1,
    headers TEXT NOT NULL DEFAULT '{}',
    updated_at TEXT NOT NULL
);

-- Skills installed for Agent mode (`agent_mode::skills`), by their folder under
-- the agent's `skills/`: where each came from, for an update, and whether it is
-- offered. A folder without a row is offered: an admin may put one there.
CREATE TABLE agent_skill (
    dir TEXT PRIMARY KEY,
    enabled INTEGER NOT NULL DEFAULT 1,
    source TEXT,
    installed_at TEXT NOT NULL
);
