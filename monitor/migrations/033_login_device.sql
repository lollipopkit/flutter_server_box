-- Devices that signed in with the password (`db::accounts`, `api::ratelimit`).
--
-- A successful login hands the client a random token; a later login that
-- carries one listed here is throttled by its address and by the device,
-- never by the account-wide counter, so failed attempts from elsewhere cannot
-- lock a known device out. Only the SHA-256 is kept. A password change empties
-- the table. Times are Unix seconds.
CREATE TABLE login_device (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token_hash TEXT NOT NULL UNIQUE,
    -- What the client called itself at its last sign-in (the login's `name`,
    -- else its User-Agent), so the operator can tell devices apart.
    label TEXT NOT NULL DEFAULT '',
    -- The address of its last sign-in.
    last_ip TEXT,
    created_at INTEGER NOT NULL,
    last_used INTEGER NOT NULL
);

CREATE INDEX idx_login_device_last_used ON login_device(last_used);
