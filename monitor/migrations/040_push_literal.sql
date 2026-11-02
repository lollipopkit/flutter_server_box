-- Push credentials in config.toml are read for `${NAME}` from now on
-- (`monitoring::push::resolve`). One row while those an older agent stored,
-- meant as typed, are still to be escaped (`push::escape_legacy`); a new
-- database (no account yet) has none to escape.
-- TODO: drop with `push::escape_legacy`.
CREATE TABLE push_literal_pending (id INTEGER PRIMARY KEY CHECK (id = 1));
INSERT INTO push_literal_pending (id) SELECT 1 WHERE EXISTS (SELECT 1 FROM users);
