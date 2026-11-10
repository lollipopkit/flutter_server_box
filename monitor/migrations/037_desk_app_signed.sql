-- Who signed an installed desk app's package (`apps::sign`): a first-party
-- key's id, or NULL for an unknown publisher. A new package for an app that
-- was signed must be signed with the same key.
ALTER TABLE desk_app_package ADD COLUMN signed_by TEXT;
