CREATE TABLE watch_tokens (
    subject TEXT NOT NULL,
    client_id TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    PRIMARY KEY (subject, client_id)
);

CREATE INDEX idx_watch_tokens_expires_at ON watch_tokens(expires_at);
