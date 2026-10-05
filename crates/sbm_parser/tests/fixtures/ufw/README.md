# ufw state as `firewall::ufw::read_script` printed it

Input for `tests/firewall_compat.rs`. Captured from ufw 0.36.2
on Ubuntu 24.04 (a privileged container), with rules added for the purpose:
both families and one, a comment in UTF-8, logging, an interface with an `_`
in its name, a routed rule, an application profile (`My App`, ports
`8000,8001/tcp`), and `limit`. `ufw app info all` lists `My App` and the
stock `OpenSSH`.

| File | State |
| --- | --- |
| `active.txt` | Enabled, `IPV6=yes` |
| `inactive_no_ipv6.txt` | The same rules, disabled, `IPV6=no` (the v6 file still holds its rules) |
