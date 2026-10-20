# Security Policy

## Supported versions

Fixes go into the latest release only, of both the app and the ServerBox Monitor agent. Before reporting, check that the issue still happens on the [latest release](https://github.com/lollipopkit/flutter_server_box/releases/latest).

## Reporting a vulnerability

Report it privately through GitHub: **[Report a vulnerability](https://github.com/lollipopkit/flutter_server_box/security/advisories/new)** (the repository's Security tab). Do not open a public issue, pull request or discussion for it.

Include:

- the affected component: the app (and platform), the Monitor agent, or the theme store and website;
- the version, and how the server is reached (SSH, Monitor agent or both);
- steps to reproduce, and what an attacker gains;
- a proof of concept, if you have one.

The report stays private until a fix is released. Credit is given in the advisory unless you ask otherwise.

## Scope

In scope: this repository's app, Monitor agent, Rust crates, theme store and website.

Out of scope:

- vulnerabilities in the servers you manage, or in third-party software the app talks to (OpenSSH, Docker, libvirt, Proxmox VE, a BMC);
- dependencies with a published advisory that do not affect ServerBox. Report those upstream; Dependabot tracks them here;
- attacks that need an already unlocked device or an already compromised server account.
