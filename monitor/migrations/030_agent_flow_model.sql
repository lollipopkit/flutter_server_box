-- What a task runs with when its account picked it: pi's model reference
-- (JSON `{"provider": …, "id": …}`) and thinking level. NULL is the machine's
-- (`agent_settings`), read at each run.
ALTER TABLE agent_flow ADD COLUMN model TEXT;
ALTER TABLE agent_flow ADD COLUMN thinking_level TEXT;
