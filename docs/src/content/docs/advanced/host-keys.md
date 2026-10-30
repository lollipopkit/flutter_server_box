---
title: Host Keys and Certificates
description: How Server Box verifies a server, and how to trust a host certificate authority
---

Server Box verifies every SSH server before it sends a password or key.

## First connection

The first time you connect to a server, Server Box shows the host key type and
its fingerprint (`SHA256:...`) and asks whether to trust it. Compare the
fingerprint with the one the server reports:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

After you accept, Server Box remembers the key for that server. If the server
later presents a different key, Server Box warns you before it connects.

## Host certificates

A server can present an OpenSSH host certificate
(`ssh-ed25519-cert-v01@openssh.com` and similar) instead of a plain host key.
Server Box supports Ed25519, ECDSA and RSA certificates.

Without a trusted certificate authority, Server Box handles a certificate as
OpenSSH does: it uses the key inside the certificate and asks about it on the
first connection, as described above. The fingerprint is the one of that key,
which matches the `Server host certificate: ... SHA256:...` line of `ssh -v`.

## Trusted certificate authorities

If your servers' host keys are signed by a certificate authority (CA), you can
trust that CA once instead of confirming each server. This is the equivalent of
an `@cert-authority` line in OpenSSH's `known_hosts`.

Open **Settings → SSH → General → Host certificate authorities** and select
**Add**:

- **Key**: the CA's public key line, for example the contents of `ca.pub`:
  `ssh-ed25519 AAAA... ca@example.com`. Ed25519, ECDSA and RSA keys are
  supported. You can also paste a whole `known_hosts` line,
  `@cert-authority *.example.com ssh-ed25519 AAAA...`; the hosts are then taken
  from it.
- **Host**: which servers the CA vouches for. The default `*` matches every
  server. It cannot be empty.

A server connects without a prompt when its certificate is signed by a matching
CA and is valid: a host certificate, within its validity period, without
critical options, not signed with SHA-1 (`ssh-rsa`), and listing the server
among its principals. Principals are compared with the address Server Box
connected to and with the address configured for the server; a certificate
without principals is valid for any host, and a principal may contain `*` and
`?`.

Otherwise, the server is asked about on the first connection as described
above, using the key inside its certificate. This includes a certificate that
a matching CA signed but that is expired or names another host, which is what
OpenSSH does too.

### Host patterns

The **Host** field uses the `known_hosts` pattern syntax:

| Pattern | Matches |
|---|---|
| `*` | Every server |
| `*.example.com` | `web.example.com`, `db.example.com` |
| `web-?.example.com` | `web-1.example.com`, not `web-10.example.com` |
| `10.0.0.*` | Addresses from `10.0.0.0` to `10.0.0.255` |
| `*.example.com,!bastion.example.com` | Every `example.com` host except `bastion` |

Separate several patterns with commas. A pattern that starts with `!` excludes
the hosts it matches. Matching ignores case.

A server on a port other than 22 is matched as `[host]:port`, as in OpenSSH.
For example, `[*.example.com]:2222` matches `web.example.com` on port 2222,
and `*.example.com` does not.
