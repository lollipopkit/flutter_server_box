---
title: Two-Factor Sync Encryption
description: How ServerBox protects synced SSH keys, passwords, and server configurations with a backup password and a 128-bit client-side Secret Key
---

To defend against server breaches and data leaks, ServerBox automatic sync (iCloud, WebDAV, and LK Cloud) uses **two-factor end-to-end encryption**. Decrypting synced data requires both your **Backup Password** and a **128-bit client-side Secret Key** that never leaves your devices.

> **Important:** ServerBox cannot see your data and cannot recover a lost Secret Key. If your Secret Key is lost on all devices, existing encrypted cloud sync data cannot be decrypted. Save it in a password manager or offline backup.

## Key hierarchy

1. **Backup Password**: Chosen by you in **Backup**. It protects local `.age` exports and guards against theft of device storage alone. You can change it without rotating your Secret Key.
2. **Secret Key (`S1-...`)**: 128 bits of OS CSPRNG entropy encoded as 30 Crockford Base32 characters (`S1-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX`) with a 22-bit BLAKE3 checksum. Mistyped characters are caught locally before any key derivation runs, and confusable characters (`I`/`L`→`1`, `O`→`0`) are normalized.
3. **Passphrase derivation**:
   ```text
   passphrase = BLAKE3_derive_key("lkc sync v1 secret-key passphrase", secret_key || len(password) || password)
   ```
4. **Sync key sealing (`identity.age`)**: The X25519 sync keypair is stored in `identity.age`, encrypted via `age scrypt` with the derived `passphrase`.
5. **Payload sealing**: Synced backup files, incremental logs, and snapshots are encrypted with `age` to the X25519 public key. Automatic remote sync rejects plaintext JSON and password-only payloads.

## Integrity and anti-rollback (LK Cloud)

When syncing personal data through LK Cloud, writes are additionally authenticated with your Ed25519 `AccountKey`:

- Files, log batches, and snapshots are signed client-side before upload.
- Clients verify the Ed25519 signature before applying downloaded data and reject unsigned or forged payloads.
- A file's signed version only rises: an older version served again is rejected.
- Log batches and snapshots apply each change only where it is newer than what the device holds, so one sent again or an older one changes nothing.

## Threat model

| Scenario | Behavior |
| --- | --- |
| Sync server or object storage breached | Attacker obtains only `identity.age` and X25519 ciphertext. Without the 128-bit Secret Key, offline brute-force against the backup password is infeasible. |
| Compromised server injects plaintext or single-factor backup | Automatic remote sync rejects unencrypted or password-only payloads. Once upgraded to two-factor encryption, a local marker permanently blocks downgrading back to bare-password sealing. |
| Compromised LK Cloud server forges writes or rolls back state | Client rejects invalid or missing Ed25519 signatures and a file version older than one already seen (`Untrusted`). |
| Secret Key lost on all devices | Neither ServerBox nor any sync backend holds a copy; cloud sync data cannot be decrypted or recovered. |

## Upgrading existing devices

- **First device (Device A)**: Keeps your existing backup password. After you confirm saving the generated Secret Key, `identity.age` is transparently re-sealed with two-factor encryption.
- **Additional Apple devices**: Receive the Secret Key automatically via iCloud Keychain when signed into the same Apple Account.
- **Additional Android / Windows / Linux devices**: Import the Secret Key by scanning the QR code or entering the `S1-...` string. Sync stays paused until imported, without blocking local SSH connections.
