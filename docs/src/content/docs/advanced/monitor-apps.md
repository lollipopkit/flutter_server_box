---
title: Monitor Apps
description: Install and manage Docker Compose apps through the Monitor panel
---

The Monitor can deploy web apps with Docker Compose and show them in the
panel's App Store and desk. An app runs on the server where the Monitor runs.
Installing, changing, or removing an app asks for the Monitor's password again.
Apps that run inside the panel
itself, installed from `.fsba` packages, are [Desk Apps](/docs/advanced/monitor-desk-apps/).

## Browse and install apps

Open **Apps → App Store** in the panel to browse by category or search by name.
An app page shows its project, publisher, version, licence, requirements, and
what its Compose files do. Select **Install** and complete the app's settings.

Before deployment, the confirmation lists the settings, images to pull, data
folders, and ports. Review these along with the project metadata and licence.
The Monitor asks for your password; acknowledge that this is third-party software
and accept the licence when the app requires it. The Monitor then downloads the
images and deploys the Compose project. The page shows the job's progress.

Some apps build an image on the server from a Dockerfile in the app's package,
because no maintained image exists. Their confirmation lists the built images
under **Built here**, and their base images among the images to pull. A build
takes longer than a download, and an update builds again from the newest base
image of the same release.

After installation, open the app from its page or **All Apps**. To edit its
settings, open the app's page and choose **Change settings**. Saving settings
deploys the app again, so it is briefly unavailable. Data already in an old
data folder is not moved to a newly selected folder.

### Ports

The Monitor checks every configured port against other containers and the
app's own running containers. For a suggested port, it chooses another free
port if the suggestion became occupied before deployment. A port you chose
explicitly is refused if it is occupied. Starting, restarting, updating, or
saving settings does not silently change a chosen port.

Port checks are partial when the Monitor cannot see the host's network namespace,
such as when the Monitor runs in a container, and for Windows host ports when the Monitor runs under WSL.
Check host port availability yourself in those setups. The app page reports
when the Monitor's port check is partial.

## App health and updates

The Monitor checks installed apps about once a minute. It reports apps as healthy,
starting, unhealthy, down, or stopped. While an app job is running, health is
not checked. A desk notification is sent when an app goes down or becomes
unhealthy, when it recovers, and when a newer catalog version is available.
Notifications appear in the panel in the reader's language when the catalog
provides a translated title.

Choose **Update** on the app page to deploy the catalog's current version. An
update is announced once for each catalog version. To check for catalog changes
now, choose **Check for new apps and versions** in the App Store.

### Remove an app

Choose **Remove** on the app page or from its window. By default, the Monitor
removes the app's containers but keeps its data so a later installation can
reuse it. Choose the option to remove data only when you no longer need it;
data paths are deleted and cannot be recovered. Removing an app takes it out
of **All Apps**.

## Where apps come from

The catalog combines three sources. When two sources contain the same app id,
the first source in this list takes precedence:

1. The folder configured by `[stacks] local_apps`, read when the Monitor starts.
2. App repositories, refreshed at Monitor startup and hourly. Use **Check for new
   apps and versions** to refresh manually.
3. Apps shipped with the Monitor.

For example, create `/srv/sbm-apps/example.web/` with a `manifest.toml` and its
Compose files, then configure:

```toml
[stacks]
local_apps = "/srv/sbm-apps"
```

Restart the Monitor after adding or changing a local app. Local app packages are
read from the configured folder; the Monitor does not copy them into the catalog.

## Shared folder and first sign-in

Apps that download, play or serve files use one shared folder, so a
downloader's files show up in a media server's library. Its subfolders are
`downloads`, `media/movies`, `media/tv`, `music`, `books`, `comics` and
`documents`. By default it is `shared/` next to the Monitor's database; set
another location with:

```toml
[stacks]
shared_dir = "/srv/media"
```

Apps run as the owner of that folder, so change its owner to choose which
user's files they create. Removing an app never deletes anything in the shared
folder.

When an app has an administrator account, the Monitor creates it with a
generated password where the app allows that. You can see the account and,
after entering the Monitor's password again, the generated password under
**Sign-in** on the app's page.

## Open apps from the ServerBox app

The **Web apps** section of the app's [Monitor tab](../monitor-agent/#the-monitor-tab)
lists the apps deployed on every server added through the Monitor,
grouped by server, with their health. An app with a newer version in the
catalog comes first, and the update button in the bar shows only those. A
server's own page also has a **Web apps** card with that server's apps.

Tap an app to open it, or its info button for its page (health, description,
version, homepage, and the **Open** button).

Tap an app to open it in the device's browser: the app asks the Monitor for a
single-use ticket and the browser enters the app through the Monitor's proxy,
as a panel window does. From then on the browser talks to the proxy with a
session of its own, so the ServerBox app may go to the background or be
closed. Deploying, updating and removing apps stay in the panel.

The browser checks the Monitor's TLS certificate itself: a certificate trusted
in the app is not trusted by the browser, so a self-signed one shows the
browser's warning. The proxy ports (or the apps host below) must be
reachable from the device.

## App windows and reverse proxies

By default, each deployed app has its own proxy port in the range 3780–3799 on
the Monitor's host. The panel enters the app through that proxy. These ports need
to be reachable by the browser; if the Monitor is behind a reverse proxy or
Cloudflare Tunnel, configure the apps host listener instead:

```toml
[stacks]
apps_url = "https://*.apps.example.com"
apps_port = 3779
```

`apps_port` defaults to `3779`. Create wildcard DNS for
`*.apps.example.com` pointing at the proxy or tunnel, and use a TLS certificate
that covers the wildcard. Each app gets a host such as
`futo-immich.apps.example.com`. The proxy must preserve the incoming `Host`
header and support WebSocket upgrades.

For Caddy, use a certificate already issued for the wildcard (or configure a
DNS challenge with a suitable provider plugin):

```text
*.apps.example.com {
    tls /etc/caddy/certs/apps.example.com.pem /etc/caddy/certs/apps.example.com-key.pem
    reverse_proxy 127.0.0.1:3779
}
```

A minimal nginx virtual host is:

```nginx
server {
    listen 443 ssl;
    server_name *.apps.example.com;
    ssl_certificate /etc/nginx/certs/apps.example.com.pem;
    ssl_certificate_key /etc/nginx/certs/apps.example.com-key.pem;

    location / {
        proxy_pass http://127.0.0.1:3779;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

For Cloudflare Tunnel, route the wildcard hostname to the local apps listener:

```yaml
ingress:
  - hostname: "*.apps.example.com"
    service: http://localhost:3779
  - service: http_status:404
```

If the panel is hosted on Cloudflare Pages, give it a custom domain on the
same site as the apps, for example `panel.example.com` alongside
`*.apps.example.com`. Safari blocks the apps' login cookies when the panel is
opened on `*.pages.dev`; other browsers retain them using partitioned cookies.
If you run multiple Monitors, give each Monitor its own wildcard domain and
certificate.

## Container backups

Open **Containers → Backups**, select a container, and choose **Back Up**. You
can back up one container or its whole Compose project. The archive contains
its volumes and bound folders. The Monitor skips bound system folders (for
example `/` and `/etc`) and bound files; the panel lists skipped mounts. You can
ask the Monitor to stop the containers while archiving, which helps avoid copying
a database while it is being written. The Monitor starts the containers again
after archiving, including when the archive job fails.

To restore, select a backup and choose **Restore**. The Monitor stops the
containers still present in the project, clears each restored mount, and
unpacks the archived data there. Restore and delete ask for your password.

By default backups are kept on the Monitor host under the database directory at
`container-backups/<backup-id>/`, with metadata in `meta.json`. To keep them on
a separate disk, mount it in **Storage** with **Let ServerBox write here**, then
choose **Where backups go → Change** in **Containers → Backups** and pick a
folder on it. The Monitor writes into `serverbox-container-backups/` there.
Backups already made stay where they are.

**Backups kept of each** sets how many backups of each container or project are
kept; after each backup the oldest beyond that number are removed. A backup is
refused when the destination has less free space than the data to archive.

To back up regularly, choose **Repeat → Every day** or **Every week** and a time
in the **Back Up** dialog. Schedules run at the server's local time and are
listed under **Scheduled** with the result of their last run.

## Storage

The **Storage** app (Linux) lists the server's disks, partitions,
filesystems and mounts, its software RAID arrays (mdadm) and ZFS pools. From it
you can:

- partition a whole disk (one GPT partition) and format it as ext4, xfs or btrfs;
- mount a filesystem, optionally with an `/etc/fstab` line so it is mounted at
  every start (the previous file is kept as `/etc/fstab.sbm-bak`), and unmount it;
- create a RAID array, add or remove a member, grow a RAID 1, 5 or 6 by one
  more working member, delete an array, and format and mount the array itself;
- create a ZFS pool (it grows by itself once its disks are replaced by larger
  ones), add disks or a spare to it, replace a failed or smaller device,
  mirror a device, bring an offline device back, take a spare out, scrub it,
  destroy it;
- grow a partition into the free space after it (a VM's disk made larger), and
  expand a mounted ext4, xfs or btrfs filesystem after the array or partition
  under it grew;
- format a partition or disk encrypted (LUKS2, with a passphrase), and lock and
  unlock it. An encrypted disk is not unlocked at boot: after a restart, unlock
  it and mount it again in Storage;
- read every disk's SMART health (temperature, hours powered on, bad sectors,
  the last self-test), see every attribute and self-test in **Details**, and
  start a short or long self-test on a disk that has SMART.

Every change asks for the sudo password of the Monitor's account and runs as
root. A disk or partition that is mounted, used as swap, or a member of an
array or pool is never partitioned, formatted or built on, nor is a firmware partition (EFI system, BIOS boot). What the system is mounted from (`/`, `/boot`, `/boot/efi`) is never unmounted. Partitioning,
formatting and building an array or pool erase what is on the disks; the
confirmation names them. mdadm, ZFS (`zfsutils-linux`) and smartmontools must be
installed for their parts to show.

Reading SMART needs root too: the app reads it on its own where sudo asks no
password, and otherwise when you click **Read disk health**.

### Maintenance and alerts

Under **Maintenance**, three tasks can run weekly or monthly: scrubbing every
ZFS pool and checking every RAID array, a short SMART test and a long SMART
test on every disk that has SMART. **Run now** starts one at once.

The schedule runs without a password. If the Monitor does not run as root, sudo
must allow its account these commands without one; the page shows the line,
for example in `/etc/sudoers.d/serverbox-storage`:

```
serverbox ALL=(root) NOPASSWD: /usr/sbin/smartctl, /usr/sbin/zpool scrub *, /usr/sbin/mdadm --action=check *
```

The Monitor also watches the storage: every five minutes the arrays and pools,
and every hour each disk's SMART (with the same sudo rule, or from the last
reading made on the page). A degraded array, a pool that is not online, a disk
whose SMART check or self-test failed, or a disk with more bad sectors than
before is reported in the notification center and through the push channels
(**Settings → Notification channels**). An array or pool that recovers is reported in
the notification center.

## Sharing

The **Sharing** app (Linux) serves folders to other computers over SMB
(Samba: Windows, macOS, Linux) and NFS (Linux, macOS). When Samba or the NFS
server is missing, the app offers to install it with the machine's package
manager (apt, dnf or apk).

- **SMB**: add a share with a name and a folder, optionally read only, open to
  guests (no account), or limited to some accounts. Samba keeps its own
  passwords: set an SMB password for each account that connects under
  **SMB passwords**. A share can take Time Machine backups from a Mac, and keep
  deleted files in a `.recycle` folder inside it.
- **NFS**: export a folder to clients (`*`, a host, an address or a network
  such as `192.168.1.0/24`), each read only or read and write, and what root
  on the client becomes (nobody by default).

ServerBox keeps the shares it makes in files of its own
(`/etc/samba/serverbox.conf`, included from `smb.conf`, and
`/etc/exports.d/serverbox.exports`) and lists shares set up elsewhere without
changing them. Every change asks for the sudo password and is checked
(`testparm`, `exportfs -ra`) before it takes effect; a change that does not
check leaves the previous configuration in place. **Connected now** lists who
uses the shares (it asks for the sudo password: Samba tells only root).
**Allow in Firewall** opens the Firewall app with TCP 445 (SMB) or 2049 (NFS)
proposed as a rule to let in, to confirm there. Pick a share's folder from the
disks mounted in Storage, or type any.
