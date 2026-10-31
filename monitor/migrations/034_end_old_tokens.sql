-- Ends every panel token issued before the one account (migration 032).
--
-- A token names its account by subject alone now, and the one account's
-- subject is a constant (`api::authz::SUBJECT`) another account may have been
-- named: its token, still in date, would act as the one account. Taken as a
-- password change, as `db::accounts::set_password_hash` makes one; the agent
-- that issued those tokens has stopped by the time this runs.
UPDATE users SET password_changed_ms = max(
    CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER),
    password_changed_ms + 1
);
