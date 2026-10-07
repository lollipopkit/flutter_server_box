-- Whether a hidden desk app keeps running (1) or is suspended (0).
ALTER TABLE desk_preferences ADD COLUMN background INTEGER NOT NULL DEFAULT 1;
