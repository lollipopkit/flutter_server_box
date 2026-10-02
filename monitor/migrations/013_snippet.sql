-- The snippet library: the scripts an operator saved to run again on this
-- machine, and the tags they filed them under.
--
-- Held by the agent rather than in the panel's localStorage: a library in a
-- browser is lost with its storage and invisible from a second one. The app
-- keeps its own set (`lib/data/store/snippet.dart`); what the two share is the
-- macro language, `sbm_parser::snippet`.
--
-- No `auto_run_on`, deliberately. The app's column names *app* servers to run
-- a snippet on when it connects to them; an agent has no such list and no
-- moment of connecting to a server that it is not itself.
--
-- No UNIQUE on `name`, though the app's table has one: the endpoint refuses a
-- duplicate before writing, where it can name the offending row
-- (`duplicateName`) rather than surface a constraint violation.
--
-- `updated_at` is RFC 3339 text bound by the writer (see migration 012 for why
-- not `DEFAULT CURRENT_TIMESTAMP`). Nothing reads it yet; a sync deciding which
-- side of a conflicting edit wins will.

CREATE TABLE snippet (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    -- As written, `${...}` macros included. Expanded when it runs
    -- (`sbm_parser::snippet::plan`), never on the way in.
    script TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    -- Display order, the operator's. A write replaces the whole set, so a move
    -- is the order the panel sent.
    position INTEGER NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX idx_snippet_position ON snippet(position);

CREATE TABLE snippet_tag (
    snippet_id TEXT NOT NULL REFERENCES snippet(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    position INTEGER NOT NULL,
    PRIMARY KEY (snippet_id, tag)
);
