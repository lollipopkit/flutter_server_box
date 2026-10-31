-- What the agent's watch over deployed web apps (`stacks::health`) needs
-- to remember across restarts.
--
-- `stopped`: an admin stopped it, so its containers being down is meant and
-- no notification says so. `update_noticed`: the catalog version a desk
-- notification already announced, so it is announced once.
ALTER TABLE stack ADD COLUMN stopped INTEGER NOT NULL DEFAULT 0;
ALTER TABLE stack ADD COLUMN update_noticed TEXT;
