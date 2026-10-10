---
title: Monitor Apps
description: Install and manage Docker Compose apps through the Monitor panel
---

The Monitor agent can deploy web apps with Docker Compose and show them in the
panel's App Store and desk. An app runs on the server where the agent runs.
You need an admin account to install, change, update, or remove an app. Any
signed-in account can browse the catalog.

## Browse and install apps

Open **Apps → App Store** in the panel to browse by category or search by name.
An app page shows its project, publisher, version, licence, requirements, and
what its Compose files do. Select **Install** and complete the app's settings.

Before deployment, the confirmation lists the settings, images to pull, data
folders, and ports. Review these along with the project metadata and licence.
The agent asks for your password; acknowledge that this is third-party software
and accept the licence when the app requires it. The agent then downloads the
images and deploys the Compose project. The page shows the job's progress.

After installation, open the app from its page or **All Apps**. To edit its
settings, open the app's page and choose **Change settings**. Saving settings
deploys the app again, so it is briefly unavailable. Data already in an old
data folder is not moved to a newly selected folder.

### Ports

The agent checks every configured port against other containers and the
app's own running containers. For a suggested port, it chooses another free
port if the suggestion became occupied before deployment. A port you chose
explicitly is refused if it is occupied. Starting, restarting, updating, or
saving settings does not silently change a chosen port.

Port checks are partial when the agent cannot see the host's network namespace,
such as when the agent runs in a container, and for Windows host ports when the agent runs under WSL.
Check host port availability yourself in those setups. The app page reports
when the agent's port check is partial.

## App health and updates

The agent checks installed apps about once a minute. It reports apps as healthy,
starting, unhealthy, down, or stopped. While an app job is running, health is
not checked. A desk notification is sent when an app goes down or becomes
unhealthy, when it recovers, and when a newer catalog version is available.
Notifications appear in the panel in the reader's language when the catalog
provides a translated title.

Choose **Update** on the app page to deploy the catalog's current version. An
update is announced once for each catalog version. To check for catalog changes
now, choose **Check for new apps and versions** in the App Store.

### Remove an app

Choose **Remove** on the app page or from its window. By default, the agent
removes the app's containers but keeps its data so a later installation can
reuse it. Choose the option to remove data only when you no longer need it;
data paths are deleted and cannot be recovered. Removing an app takes it out
of **All Apps**.

## Where apps come from

The catalog combines three sources. When two sources contain the same app id,
the first source in this list takes precedence:

1. The folder configured by `[stacks] local_apps`, read when the agent starts.
2. App repositories, refreshed at agent startup and hourly. Use **Check for new
   apps and versions** to refresh manually.
3. Apps shipped with the agent.

For example, create `/srv/sbm-apps/example.web/` with a `manifest.toml` and its
Compose files, then configure:

```toml
[stacks]
local_apps = "/srv/sbm-apps"
```

Restart the agent after adding or changing a local app. Local app packages are
read from the configured folder; the agent does not copy them into the catalog.

## App windows and reverse proxies

By default, each deployed app has its own proxy port in the range 3780–3799 on
the agent's host. The panel enters the app through that proxy. These ports need
to be reachable by the browser; if the agent is behind a reverse proxy or
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
If you run multiple agents, give each agent its own wildcard domain and
certificate.

## Container backups

Open **Containers → Backups**, select a container, and choose **Back Up**. You
can back up one container or its whole Compose project. The archive contains
its volumes and bound folders. The agent skips bound system folders (for
example `/` and `/etc`) and bound files; the panel lists skipped mounts. You can
ask the agent to stop the containers while archiving, which helps avoid copying
a database while it is being written. The agent starts the containers again
after archiving, including when the archive job fails.

To restore, select a backup and choose **Restore**. The agent stops the
containers still present in the project, clears each restored mount, and
unpacks the archived data there. Restore and delete ask for your password.

By default backups are kept on the agent host under the database directory at
`container-backups/<backup-id>/`, with metadata in `meta.json`. To keep them on
a separate disk, mount it in **Storage** with **Let ServerBox write here**, then
choose **Where backups go → Change** in **Containers → Backups** and pick a
folder on it. The agent writes into `serverbox-container-backups/` there.
Backups already made stay where they are.

**Backups kept of each** sets how many backups of each container or project are
kept; after each backup the oldest beyond that number are removed. A backup is
refused when the destination has less free space than the data to archive.

To back up regularly, choose **Repeat → Every day** or **Every week** and a time
in the **Back Up** dialog. Schedules run at the server's local time and are
listed under **Scheduled** with the result of their last run.

## Storage

The **Storage** app (Linux, admin) lists the server's disks, partitions,
filesystems and mounts, its software RAID arrays (mdadm) and ZFS pools. From it
you can:

- partition a whole disk (one GPT partition) and format it as ext4, xfs or btrfs;
- mount a filesystem, optionally with an `/etc/fstab` line so it is mounted at
  every start (the previous file is kept as `/etc/fstab.sbm-bak`), and unmount it;
- create a RAID array, add or remove a member, delete an array;
- create a ZFS pool, scrub it, destroy it;
- start a SMART self-test.

Every change asks for the sudo password of the agent's account and runs as
root. A disk or partition that is mounted, used as swap, or a member of an
array or pool is never partitioned, formatted or built on. Partitioning,
formatting and building an array or pool erase what is on the disks; the
confirmation names them. mdadm, ZFS (`zfsutils-linux`) and smartmontools must be
installed for their parts to show.
