-- The snippet library: the scripts the operator saved to run again, and the
-- tags they filed them under.
--
-- Held here rather than in the panel's localStorage, and edited here by the
-- panel, because a snippet is a record of what to run *on this machine*: the
-- panel is a browser that can be opened anywhere and an agent that answers for
-- one machine, and a library in the browser would be lost with its storage and
-- invisible from a second browser. The app keeps its own set over SSH
-- (`lib/data/model/server/snippet.dart`); this is the agent's copy, and the
-- macro language the two share is `sbm_parser::snippet`.
--
-- No `auto_run_on`, deliberately. The field names *app* servers — "run this
-- when I connect to this one" — and its values are ids of records the app
-- holds. An agent has no list to resolve them against and no moment of
-- connecting to a server that it is not itself, so a column here would hold
-- strings neither client could act on. `TODO`: when sync arrives, the app's
-- record is the one that owns a snippet's auto-run set.
--
-- No UNIQUE on `name`, though the app's own table has one. Both clients refuse
-- a duplicate name before writing, which is where it can be answered as a code
-- naming the offending row (`duplicate_name`, like `/desktop`'s refusals)
-- rather than as a constraint violation with nothing to point at.
--
-- Timestamps are RFC 3339 text bound by the writer, the shape migration 009 put
-- `access_log.timestamp` into — see migration 011's comment for why
-- `DEFAULT CURRENT_TIMESTAMP` is not used. `updated_at` is not read by this
-- endpoint: the order is `position`, which the operator chooses. It is here
-- because a sync has to decide which side of a conflicting edit wins, and that
-- question is asked of a timestamp.

CREATE TABLE snippet (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    -- The script as written, `${...}` macros included. Saved as text and
    -- expanded at the moment of running (`sbm_parser::snippet::plan`), never on
    -- the way in: a snippet is a command to be typed into a live shell, and the
    -- values in it — a host, a working directory — are facts about the session
    -- it is run in rather than about the library.
    script TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    -- Display order within the library, chosen by the operator. A replace
    -- writes the whole set, so this is where a move is expressed: the panel
    -- sends the list it wants and the order is what it sent.
    position INTEGER NOT NULL,
    updated_at TEXT NOT NULL
);

-- The list is read in order and that is the only way this table is read whole.
CREATE INDEX idx_snippet_position ON snippet(position);

CREATE TABLE snippet_tag (
    snippet_id TEXT NOT NULL REFERENCES snippet(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    -- Position among this snippet's tags. A tag is a word the operator chose,
    -- so the order is theirs to set and is not sorted here.
    position INTEGER NOT NULL,
    PRIMARY KEY (snippet_id, tag)
);
