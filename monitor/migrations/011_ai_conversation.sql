-- The Agent's conversations, and the items they are made of.
--
-- The app keeps the same thing (`lib/data/store/db.dart`, `agent_conversation`)
-- as one JSON blob per conversation, because there it is a device-local record
-- and every read is "draw this conversation". Here the same record is read
-- differently: the follow stream asks for everything after a position, and the
-- turn asks whether a call is still unanswered. Both are questions about one
-- item, so an item is a row.
--
-- One thing is deliberately absent, and it is the state machine rather than a
-- column. A `function_call` item with no `function_output` answering its
-- `call_id` **is** the awaiting-review state — the same invariant the app
-- carries — so nothing here records a turn's state. A turn that is still
-- running exists only inside this process, and a restart ends it; that is also
-- why the guard against two turns in one conversation is in memory while
-- migration 010's guard against two benchmark runs is a database constraint:
-- a run is an OS process that outlives the agent (`setsid`), a turn is a task
-- that cannot.
--
-- No `server_id`, for `benchmark_run`'s reason: this agent is the server.
--
-- No CHECK on `kind`. The values are spelled by name and a new one is a change
-- a later build may make; SQLite can only change a constraint by rebuilding the
-- table, which would take every item with it.
--
-- Timestamps are RFC 3339 text bound by the writer, the shape migration 009 put
-- `access_log.timestamp` into. `DEFAULT CURRENT_TIMESTAMP` is not used: it
-- writes `YYYY-MM-DD HH:MM:SS`, which does not compare against the text
-- everything else in this database is written as.

CREATE TABLE ai_conversation (
    id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    -- What the list is ordered by and what the per-conversation cap keeps. Not
    -- a record of when a *device* last touched the row — the app's distinction,
    -- and here there is one device: the agent.
    updated_at TEXT NOT NULL,
    -- Taken from the first user message so that both clients read the same name
    -- for the same conversation without either naming it.
    title TEXT NOT NULL DEFAULT '',
    -- The model that last answered. Kept because it is a property of the
    -- conversation: a resumed turn wants the model that produced what is above
    -- it, or the operator has changed it and the change is worth seeing. The
    -- endpoint is not kept — it is a property of the agent, this conversation
    -- cannot be moved to another one, and the turn that resumes it necessarily
    -- talks to the endpoint configured now.
    model TEXT NOT NULL DEFAULT '',
    -- Cumulative tokens the endpoint reported for this conversation.
    -- `stream_options.include_usage` is an OpenAI extension that a
    -- compatible endpoint may ignore, so 0 means it reported none rather than
    -- that none were used.
    prompt_tokens INTEGER NOT NULL DEFAULT 0,
    completion_tokens INTEGER NOT NULL DEFAULT 0
);

-- The list is newest first and that is the only way the table is read as a
-- whole.
CREATE INDEX idx_ai_conversation_updated_at ON ai_conversation(updated_at DESC);

CREATE TABLE ai_message (
    conversation_id TEXT NOT NULL REFERENCES ai_conversation(id) ON DELETE CASCADE,
    -- The item's position, from 0. It is what the follow stream asks from
    -- ("everything after this"), what the model-facing history is assembled in,
    -- and what the primary key orders by — so no separate index is needed for
    -- the lookup that answers whether a call is unanswered, since that is a
    -- range of one conversation's rows.
    ordinal INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    -- 'message' | 'function_call' | 'function_output' | 'notice'. The first
    -- three are the protocol's items; a notice is this agent saying why a turn
    -- stopped, and **no notice is ever sent to the model**.
    kind TEXT NOT NULL,
    -- 'user' | 'assistant', and empty for a kind that has no side. Stored by
    -- name, never by index: these rows outlive the build that wrote them.
    role TEXT NOT NULL DEFAULT '',
    -- For a 'message', what was said. For a 'function_output', the result
    -- envelope verbatim — the exact string sent back to the model, so what a
    -- client draws and what the model was told cannot disagree. For a 'notice',
    -- one of a few fixed codes and never a sentence: the client phrases it in
    -- the viewer's language.
    content TEXT NOT NULL DEFAULT '',
    -- `reasoning_content`, kept out of `content` because it is drawn and never
    -- sent back.
    reasoning TEXT NOT NULL DEFAULT '',
    -- A 'function_call' answers to this id. NULL says the kind has no such
    -- field, which is a different claim from an empty one.
    call_id TEXT,
    tool TEXT,
    -- The model's arguments as the JSON object they arrived as, never a
    -- re-serialisation of the fields parsed out of them.
    arguments TEXT,
    -- What `sbm_parser::ai_risk::classify` said about the command the arguments
    -- carry, as it said it when the call was created. That value is what the
    -- reviewer was shown and what decided whether the call ran unreviewed, and
    -- it is decided once: a call is answered or a person approves it, so no
    -- later turn re-decides an old one.
    risk TEXT,
    PRIMARY KEY (conversation_id, ordinal)
);

-- One answer per call, enforced here rather than by a check in the handler.
--
-- Two panel actions arriving together would both read the same call as
-- unanswered and both run it, which is the one mistake in this endpoint that
-- cannot be undone: a command runs twice. With this, the second insert fails
-- and its request is refused, so the row that decides an answer is unique is
-- the database's rather than a lock's.
CREATE UNIQUE INDEX idx_ai_message_one_output_per_call
    ON ai_message(conversation_id, call_id) WHERE kind = 'function_output';
