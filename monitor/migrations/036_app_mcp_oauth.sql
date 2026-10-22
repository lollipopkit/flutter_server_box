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

-- An MCP server signed in to with OAuth (`agent_mode::mcp_oauth`), by its id
-- (`fl_pi_llm::mcp::server_id` of its address): where tokens come from and
-- the tokens, never read back out over the API.
CREATE TABLE mcp_oauth (
    server_id TEXT PRIMARY KEY,
    url TEXT NOT NULL,
    token_endpoint TEXT NOT NULL,
    client_id TEXT NOT NULL,
    client_secret TEXT,
    resource TEXT NOT NULL,
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    -- Milliseconds since the epoch; NULL when the server did not say.
    expires_at INTEGER,
    updated_at TEXT NOT NULL
);
