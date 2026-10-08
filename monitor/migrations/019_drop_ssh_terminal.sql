-- The terminal no longer logs into the local sshd: a shell is the agent's own
-- (`shell`). Gone with it are the pinned host key of that sshd and the
-- `ssh_terminal` grant, which no role keeps — `Grants` refuses a field it
-- does not know, so leaving it in a stored role would make that role
-- unreadable.

DROP TABLE IF EXISTS ssh_known_hosts;

UPDATE roles
SET grants = json_remove(grants, '$.ssh_terminal'),
    updated_at = strftime('%Y-%m-%dT%H:%M:%S', 'now') || '+00:00'
WHERE grants IS NOT NULL AND json_type(grants, '$.ssh_terminal') IS NOT NULL;
