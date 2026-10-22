-- The first-party desk apps the agent ships are installed on their own
-- (`api::apps::keep_first_party`); one the admin removed is named here so it
-- stays removed until installed again from the App Store.
CREATE TABLE desk_app_declined (
    app_id TEXT PRIMARY KEY,
    declined_at TEXT NOT NULL
);
