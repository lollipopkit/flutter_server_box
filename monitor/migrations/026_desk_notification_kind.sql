-- Stack notifications carry a stable kind and structured parameters so the
-- panel can render them in the reader's language. Existing rows remain usable
-- through their English subject and body fallback.
ALTER TABLE desk_notification ADD COLUMN kind TEXT;
ALTER TABLE desk_notification ADD COLUMN params TEXT;
