-- A deployed app's MCP servers (`[[mcp]]` of its manifest) as Agent mode uses
-- them (`agent_mode::mcp`): on or off, and the token an admin gave one that
-- asks for it (`auth.asked`), never read back out. Where a server is and what
-- else it is sent are worked out from the deployed app each time, so a new
-- port or a removed app never leaves a stale address here.
CREATE TABLE stack_mcp (
    stack_id TEXT NOT NULL REFERENCES stack(id) ON DELETE CASCADE,
    -- Its place in the manifest's `[[mcp]]`.
    idx INTEGER NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    token TEXT,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (stack_id, idx)
);
