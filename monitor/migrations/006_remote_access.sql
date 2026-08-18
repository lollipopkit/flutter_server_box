-- Tables backing the WebSocket paths to the local sshd (see
-- core::remote_access and api::ws).

-- Who opened a tunnel or a terminal, from where, and whether it worked.
--
-- Deliberately records no credentials of any kind: `ssh_user` is the account
-- name a terminal authenticated as, never the password, key or passphrase
-- used to do it. `subject` is the panel account that authorised the ticket,
-- which is a different identity from `ssh_user` and worth keeping separate —
-- one panel login can open sessions as several system users.
CREATE TABLE access_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    -- 'ticket' | 'tunnel' | 'terminal'
    kind TEXT NOT NULL,
    -- 'open' | 'attach' | 'detach' | 'close' | 'denied'
    action TEXT NOT NULL,
    -- panel account (JWT subject)
    subject TEXT,
    remote_ip TEXT,
    -- system account for terminal sessions, NULL for tunnels (the agent never
    -- sees which user the app authenticates as — that traffic is encrypted)
    ssh_user TEXT,
    -- 'ok' | 'denied' | 'error'
    result TEXT NOT NULL,
    detail TEXT
);

CREATE INDEX idx_access_log_timestamp ON access_log(timestamp);

-- Cleaned up by the existing retention_policies mechanism rather than a
-- bespoke path; `DataCleanupService::POLICY_TABLES` carries the matching
-- allowlist entry. 90 days is long enough to investigate an incident found
-- weeks later without turning the log into the biggest table in the file.
INSERT INTO retention_policies (table_name, retention_days) VALUES
('access_log', 90);

-- Trust-on-first-use record for the sshd the browser terminal connects to.
--
-- The agent reaches sshd over loopback, where a man in the middle needs local
-- access already — but pinning still catches the case that matters: something
-- else taking over the port after a restart. A mismatch is refused rather
-- than re-pinned; recovering is a deliberate act (delete the row).
--
-- The app's tunnel has no row here: it verifies the host key itself, at its
-- own end, against its own store. The agent is a byte relay on that path and
-- could not check it even if it wanted to.
CREATE TABLE ssh_known_hosts (
    addr TEXT PRIMARY KEY,
    key_type TEXT NOT NULL,
    fingerprint TEXT NOT NULL,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP
);
