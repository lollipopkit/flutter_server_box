-- Agent mode (`agent_mode`): tasks an AI agent runs on this machine for an
-- account. A task is a pi session — the conversation, every tool call and its
-- output — kept as a JSONL file under `<database dir>/agent/`, the format the
-- apps keep theirs in; this row is what lists, orders and owns it.
--
-- Text times are RFC 3339, bound by the writer (see migration 012).

CREATE TABLE agent_flow (
    -- Also the pi session's id.
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    -- `queued` | `running` | `waiting` | `done` | `failed` | `cancelled`.
    status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'waiting', 'done', 'failed', 'cancelled')),
    -- What the timeline shows under the title: what it is doing, or what it did.
    line TEXT NOT NULL DEFAULT '',
    -- JSON array of the areas it worked in (`status`, `process`, `service`,
    -- `container`, `files`, `system`), first use first.
    areas TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    -- When it last started running; NULL while queued.
    started_at TEXT,
    finished_at TEXT
);

CREATE INDEX agent_flow_user ON agent_flow (user_id, updated_at);

-- What the agent runs with. One row, set by an admin; absent is unconfigured.
CREATE TABLE agent_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    -- pi's model reference, JSON `{"provider": …, "id": …}`.
    model TEXT NOT NULL,
    -- pi's thinking level: `off` | `minimal` | `low` | `medium` | `high`.
    thinking_level TEXT NOT NULL DEFAULT 'off',
    -- Tasks running at once; more wait their turn.
    max_running INTEGER NOT NULL DEFAULT 3 CHECK (max_running BETWEEN 1 AND 8),
    updated_at TEXT NOT NULL
);

-- Endpoints an admin added (pi's custom providers), in order.
CREATE TABLE agent_provider (
    id TEXT PRIMARY KEY,
    position INTEGER NOT NULL,
    name TEXT NOT NULL,
    -- `openai-completions` | `openai-responses` | `anthropic-messages` |
    -- `google-generative-ai`.
    api TEXT NOT NULL,
    base_url TEXT NOT NULL,
    -- Plain HTTP to this endpoint is allowed.
    allow_insecure INTEGER NOT NULL DEFAULT 0,
    -- JSON array of `{"id": …, "name"?: …}`; empty lists them from the endpoint.
    models TEXT NOT NULL DEFAULT '[]'
);

-- A provider's credential, pi's JSON (`{"type": "api_key", "key": …}`), for
-- a built-in provider or one above. Write-only over the API, like every
-- credential in this agent's state.
CREATE TABLE agent_credential (
    provider_id TEXT PRIMARY KEY,
    credential TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
