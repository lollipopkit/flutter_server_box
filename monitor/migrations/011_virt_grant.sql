-- The `virt` grant: the hypervisors and BMCs the agent reaches for the panel
-- (Proxmox VE, libvirt, Redfish).
--
-- A role that already holds `shell` gets it. A shell runs as the agent's own
-- account, which can read the credentials those pages use and reach the same
-- hosts, so withholding `virt` from it would only hide the pages. Every other
-- role starts without it.
--
-- Only rows that have not said: a role saved with `virt` either way keeps it.
-- A built-in role still NULL is decided later by `db::bootstrap`, which reads
-- `Grants::from_legacy` and gives `virt` to a role with `shell` there too.

UPDATE roles
SET grants = json_set(grants, '$.virt', json('true'))
WHERE grants IS NOT NULL
  AND json_extract(grants, '$.shell') = 1
  AND json_type(grants, '$.virt') IS NULL;
