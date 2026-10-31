---
title: Monitor Settings Backup
description: Back up the Monitor's settings to a WebDAV folder, encrypted with your passphrase, and restore them
---

The Monitor can back up its own settings to a WebDAV folder: the account
password, snippets, remote desktops, BMC and PVE connections, desk preferences
and themes, Agent mode settings, push channels and monitoring rules. Metrics
history, the audit log, sessions, installed packages and deployed web apps are
left out.

Open **Settings → Settings backup** in the panel.

## Set it up

1. Enter the folder's address (one folder per server, for example
   `https://dav.example.com/serverbox/web-1/`), the user name and the password,
   and press **Test**. The folder is made on the first backup.
2. Press **Save** and enter the panel password.
3. Press **Set passphrase**. The first backup is made right after.

The address must be HTTPS. Plain HTTP works to the same machine, or to another
one after you turn on **Allow plain HTTP**; the backups stay encrypted, but the
WebDAV password is sent unencrypted.

## How backups are made

- The settings are checked every 10 minutes. A backup is made when they
  changed, and once a day when only values that change on their own did (the
  last run of a schedule, refreshed sign-in tokens).
- The newest 10 are kept (change it under **Backups kept**). A backup can be at
  most 100 MB. Each server's files carry its own id (`<server>`), so servers
  sharing a folder never remove each other's backups.
- When a backup fails, the desk and the push channels say so once; the desk
  says so again when backups work again.

## Encryption

Each backup is a [age](https://age-encryption.org) file encrypted to a key. The
key's secret half is in the folder too, as `serverbox-monitor-key-<server>-<id>.age`,
encrypted with your passphrase. The Monitor keeps only the public half, so it
backs up without the passphrase and cannot read its own backups.

**If you lose the passphrase, the backups cannot be restored.** A new
passphrase applies to backups from then on; older backups keep the passphrase
they were made with.

The files are plain age, so you can open them without ServerBox:

```sh
age -d serverbox-monitor-key-<server>-<id>.age > key.txt   # asks the passphrase
age -d -i key.txt serverbox-monitor-<server>-<time>-<id>.tar.gz.age | tar -xz
```

The archive holds `manifest.json`, `config.toml`, `settings.db` (SQLite) and
the files the settings name (`blobs/`).

## Restore

In the panel, press **Restore** next to a backup and enter its passphrase, then
the panel password. The settings are replaced; the server's history, its
listen address, TLS files, database location and where backups go stay. The
account password becomes the one in the backup, so every device signs in
again. A Monitor run as a systemd service (as the installer sets it up) or under
OpenRC restarts by itself; otherwise, in a container too, restart it.

On a new machine, before or after installing the Monitor, restore from the
command line in its working directory:

```sh
server_box_monitor backup restore --url https://dav.example.com/serverbox/web-1/ --user me
```

It asks the WebDAV password and the passphrase (or reads them from the
variables `--password-env` and `--passphrase-env` name), restores the newest
backup (`--name` picks another; a folder several servers back up to needs it),
and keeps backing up to the same folder as that server.
`server_box_monitor backup list` lists the backups and `backup run` makes one
now.
