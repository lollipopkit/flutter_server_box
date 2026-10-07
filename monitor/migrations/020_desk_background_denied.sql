-- Apps that may not run in the background even while background running is on.
CREATE TABLE desk_background_denied (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    app_id TEXT NOT NULL,
    PRIMARY KEY (user_id, app_id)
);
