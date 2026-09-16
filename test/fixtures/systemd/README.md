# systemd output as systemctl printed it

Input for the `systemd details` group in `test/unit/server/service_manager_test.dart`.
Captured from systemd 258 on a NixOS machine, with three transient units made
for the purpose (`systemd-run`): one that exits 3 (`sbfail`), one still
running (`sbrun`), and a timer with a monotonic trigger (`sbtimer`). Trimmed
to those and a few units every systemd machine has.

| File | Command |
| --- | --- |
| `list_units.txt` | `SystemdServiceManager.listCommand(ServiceScope.system)` |
| `show.txt` | `SystemdServiceManager.detailsCommand(ServiceScope.system)`, first line the server's `date +%s` |
| `journal.txt` | `journalctl --no-pager --output=short-iso -n 5 -u sbfail.service` |
