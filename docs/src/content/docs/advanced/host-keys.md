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
  supported.
- **Host**: which servers the CA vouches for. The default `*` matches every
  server.

A server whose certificate is signed by a matching CA connects without a
prompt. Server Box then checks the certificate and refuses the connection if:

- the certificate is expired or not yet valid,
- it is a user certificate rather than a host certificate,
- its principals do not include the host name or address configured for the
  server (a certificate without principals is valid for any host),
- it has critical options, or
- the CA signed it with SHA-1 (`ssh-rsa`).

A server whose certificate is not signed by a matching CA is asked about on the
first connection, as before.

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
