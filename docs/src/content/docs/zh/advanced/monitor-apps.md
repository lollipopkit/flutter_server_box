---
title: Monitor 应用
description: 通过 Monitor 面板安装和管理 Docker Compose 应用
---

Monitor agent 可以通过 Docker Compose 部署 Web 应用，并在面板的 App Store
和桌面中显示。应用运行在 agent 所在的服务器上。安装、修改、更新或移除应用需要
admin 账号；所有已登录账号都可以浏览目录。

## 浏览和安装应用

在面板中打开 **Apps → App Store**，按类别浏览或按名称搜索。应用页面会显示项目、发布者、
版本、许可证、运行要求，以及 Compose 文件的作用。选择 **Install** 并填写应用设置。

部署前的确认页面会列出设置、要拉取的镜像、数据目录和端口。请同时检查这些内容、项目
信息和许可证。agent 会要求输入密码；确认这是第三方软件，并在应用要求时接受许可证。
之后 agent 会下载镜像并部署 Compose 项目。页面会显示任务进度。

安装后，可从应用页面或 **All Apps** 打开应用。要修改设置，请打开应用页面并选择
**Change settings**。保存设置会重新部署应用，期间应用会短暂不可用。旧数据目录中的数据
不会移动到新选择的目录。

### 端口

agent 会将每个配置端口与其他容器及应用自身运行的容器进行检查。如果建议端口在部署前
被占用，agent 会改用另一个空闲端口。若你明确指定了端口，而该端口已被占用，部署会被拒绝。
启动、重启、更新或保存设置时，不会静默更改已选端口。

如果 agent 无法看到主机的网络命名空间（例如 agent 运行在容器中），或 agent 运行在 WSL
中而检查 Windows 主机端口，端口检查会不完整。在这些环境中，请自行确认主机端口是否可用。端口检查
不完整时，应用页面会显示提示。

## 应用健康状态和更新

agent 大约每分钟检查一次已安装应用，并报告健康、启动中、异常、已停止运行或已停止状态。
应用任务运行期间不会检查健康状态。应用停止或状态异常、恢复运行，以及目录中出现比当前
版本更新的版本时，桌面会收到通知。如果目录提供了已翻译的标题，通知会使用阅读者当前的
语言显示。

在应用页面选择 **Update**，即可部署目录中的当前版本。每个目录版本只会通知一次。要立即
检查目录是否有变化，请在 App Store 中选择 **Check for new apps and versions**。

### 移除应用

在应用页面或应用窗口中选择 **Remove**。默认情况下，agent 会移除应用容器并保留数据，
之后重新安装时可以继续使用。只有在不再需要数据时才选择同时删除数据；数据目录会被删除，
无法恢复。移除应用后，它会从 **All Apps** 中消失。

## 应用来源

目录合并以下三个来源。若多个来源包含同一个 app id，则按以下顺序优先使用最前面的来源：

1. `[stacks] local_apps` 配置的目录，agent 启动时读取。
2. 应用仓库，agent 启动时和之后每小时刷新一次。也可以选择 **Check for new apps and
   versions** 手动刷新。
3. 随 agent 附带的应用。

例如，创建 `/srv/sbm-apps/example.web/`，在其中放置 `manifest.toml` 和 Compose 文件，
然后配置：

```toml
[stacks]
local_apps = "/srv/sbm-apps"
```

添加或修改本地应用后，请重启 agent。本地应用包从配置的目录读取，不会被复制到目录缓存中。

## 应用窗口和反向代理

默认情况下，每个已部署应用会在 agent 所在的主机上使用一个独立代理端口，范围为
3780–3799。面板通过该代理进入应用。浏览器需要能够访问这些端口；如果 agent 位于反向
代理或 Cloudflare Tunnel 后面，请改用应用主机名监听器：

```toml
[stacks]
apps_url = "https://*.apps.example.com"
apps_port = 3779
```

`apps_port` 默认值为 `3779`。创建指向代理或 tunnel 的 `*.apps.example.com` 通配符
DNS，并使用覆盖该通配符域名的 TLS 证书。每个应用会分配一个主机名，例如
`futo-immich.apps.example.com`。代理必须保留传入的 `Host` header，并支持 WebSocket 升级。

Caddy 示例，使用已签发的通配符证书（也可以配置支持的 provider plugin 进行 DNS challenge）：

```text
*.apps.example.com {
    tls /etc/caddy/certs/apps.example.com.pem /etc/caddy/certs/apps.example.com-key.pem
    reverse_proxy 127.0.0.1:3779
}
```

nginx 虚拟主机示例：

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

Cloudflare Tunnel 可将通配符主机名转发到本地应用监听器：

```yaml
ingress:
  - hostname: "*.apps.example.com"
    service: http://localhost:3779
  - service: http_status:404
```

如果面板托管在 Cloudflare Pages，请为它配置与应用同站点的自定义域名，例如
`panel.example.com` 和 `*.apps.example.com`。当面板使用 `*.pages.dev` 域名时，Safari
会阻止应用的登录 cookie；其他浏览器会通过 partitioned cookies 保留这些 cookie。如果
运行多个 agent，请为每个 agent 使用独立的通配符域名和证书。

## 容器备份

打开 **Containers → Backups**，选择容器并点击 **Back Up**。可以备份单个容器，或其整个
Compose 项目。归档包含其卷和 bind mount 的文件夹。agent 会跳过主机系统文件夹（例如 `/`
和 `/etc`）以及 bind mount 的文件；面板会列出被跳过的挂载项。归档期间可以让 agent 停止
容器，避免数据库正在写入时被复制。归档任务完成或失败后，agent 都会重新启动容器。

要恢复数据，请选择备份并点击 **Restore**。agent 会停止项目中仍存在的容器，清空每个
待恢复的挂载位置，再解压归档数据。恢复和删除操作都会要求输入密码。

默认情况下，备份保存在 agent 主机上的数据库目录下：`container-backups/<backup-id>/`，元数据位于
`meta.json`。要保存到单独的硬盘，先在 **Storage** 中挂载该硬盘并勾选 **Let ServerBox write
here**，再在 **Containers → Backups** 中选择 **Where backups go → Change**，选中该硬盘上的文件夹。
agent 会在其中创建 `serverbox-container-backups/` 并写入备份。已有的备份不会移动。

**Backups kept of each** 设置每个容器或项目保留的备份数量；每次备份完成后，超出数量的最旧备份会被删除。
目标位置的可用空间小于待归档数据时，备份会被拒绝。

要定期备份，在 **Back Up** 对话框中选择 **Repeat → Every day** 或 **Every week** 以及时间。计划任务按
服务器本地时间运行，列在 **Scheduled** 下，并显示上次运行的结果。

## 存储

**Storage** 应用（Linux，管理员）列出服务器的硬盘、分区、文件系统和挂载点，以及软件 RAID 阵列（mdadm）
和 ZFS 存储池。可以执行：

- 对整块硬盘分区（一个 GPT 分区），并格式化为 ext4、xfs 或 btrfs；
- 挂载文件系统，可选写入 `/etc/fstab` 以便每次启动时自动挂载（原文件保存为 `/etc/fstab.sbm-bak`），以及卸载；
- 创建 RAID 阵列，添加或移除成员，删除阵列；
- 创建 ZFS 存储池，执行 scrub，销毁存储池；
- 启动 SMART 自检。

每项更改都会要求输入 agent 账户的 sudo 密码，并以 root 身份运行。已挂载、用作 swap、或属于阵列或存储池的
硬盘和分区不会被分区、格式化或用于创建阵列，固件分区（EFI 系统分区、BIOS boot）也一样。系统所在的挂载点（`/`、`/boot`、`/boot/efi`）不能卸载。分区、格式化以及创建阵列或存储池会清除硬盘上的数据，确认对话框会
列出这些硬盘。相应功能需要安装 mdadm、ZFS（`zfsutils-linux`）和 smartmontools。
