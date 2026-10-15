-- The desk's first-run guide: when the account walked through it, or skipped
-- it. A row whose column is NULL — or no row at all — is an account that has
-- not seen the guide yet.
--
-- Whether it is shown is the agent's answer, so an upgraded agent does not
-- greet someone who has been using the desk for months: every account that
-- used the desk is marked here.

ALTER TABLE desk_preferences ADD COLUMN onboarded_at TEXT;

UPDATE desk_preferences SET onboarded_at = strftime('%Y-%m-%dT%H:%M:%S', 'now') || '+00:00';

-- Accounts that used the desk are past it. One that opened a window saved a
-- session but saved no preference until it arranged something, so it has no
-- row to mark: it gets one, filled with the panel's defaults as
-- `registry.svelte.ts`'s `defaultDock()` has them in this release — the desk
-- a row-less account is drawn with.
WITH pinned(position, app_id) AS (
    SELECT 0, 'serverbox.status' UNION ALL
    SELECT 1, 'serverbox.files' UNION ALL
    SELECT 2, 'serverbox.terminal' UNION ALL
    SELECT 3, 'serverbox.containers' UNION ALL
    SELECT 4, 'serverbox.virt' UNION ALL
    SELECT 5, 'serverbox.settings'
)
INSERT INTO desk_dock (user_id, position, app_id)
SELECT s.user_id, pinned.position, pinned.app_id
FROM (SELECT DISTINCT user_id FROM desk_session) s
CROSS JOIN pinned
WHERE NOT EXISTS (SELECT 1 FROM desk_preferences p WHERE p.user_id = s.user_id);

INSERT INTO desk_preferences (user_id, accent, wallpaper, wallpaper_fit, background, theme, onboarded_at, updated_at)
SELECT DISTINCT s.user_id, NULL, 'preset:bloom', 'cover', 1, NULL,
    strftime('%Y-%m-%dT%H:%M:%S', 'now') || '+00:00',
    strftime('%Y-%m-%dT%H:%M:%S', 'now') || '+00:00'
FROM desk_session s
WHERE NOT EXISTS (SELECT 1 FROM desk_preferences p WHERE p.user_id = s.user_id);
