# firewalld state as `FirewalldManager.readScript` printed it

Input for `test/unit/server/firewalld_manager_test.dart`. Captured from
firewalld 1.3.4 on Rocky Linux 9 (a privileged container, the daemon started
by hand on a system bus), configured for the purpose:

- `internal` has `eth0`; `trusted` (ACCEPT) has the source `10.8.0.0/24`;
  `public` is the default zone
- `public`: `http`, ports `8080/tcp` and `6000-6010/udp`, masquerade, a
  forwarded port, a priority `-10` rich rule dropping `198.51.100.7`, and one
  rejecting `ssh` from `203.0.113.0/24`
- `7777/tcp` added to the runtime only, `5555/tcp` to the permanent only
- a service of its own, `myapp`, under `/etc/firewalld/services`

| File | State |
| --- | --- |
| `running.txt` | The daemon running: both configurations, policies, services |
| `stopped.txt` | The daemon stopped: the permanent one, through `firewall-offline-cmd` |
