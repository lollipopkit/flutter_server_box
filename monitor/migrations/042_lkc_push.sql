-- This install as a push sender of the LK Cloud account (`lkc::push`): the
-- key it registers under, made once and kept across sign-ins so a mute the
-- person set holds, and the sender homebase answered for it, per account.
CREATE TABLE lkc_push (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    sender_key TEXT NOT NULL,
    -- Homebase's sender id, and the account (`User.id`) it was registered
    -- for; registered again when the account differs or homebase forgot it.
    sender_id TEXT,
    user_id TEXT
);
