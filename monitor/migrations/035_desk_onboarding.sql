-- The desk's first-run guide: an account with a row has walked through it or
-- skipped it. Its own table, so saving preferences never touches it.
CREATE TABLE desk_onboarding (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    done_at TEXT NOT NULL
);

-- An account that already used the desk is not greeted after the upgrade.
INSERT INTO desk_onboarding (user_id, done_at)
SELECT user_id, strftime('%Y-%m-%dT%H:%M:%S', 'now') || '+00:00'
FROM (SELECT user_id FROM desk_preferences UNION SELECT user_id FROM desk_session);
