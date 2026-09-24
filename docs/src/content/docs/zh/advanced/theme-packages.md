---
title: 主题包
description: 编写、安装与发布主题包
---

`.fsbt` 是一个 ZIP 压缩包。根目录包含 `manifest.toml`（UTF-8 TOML）、可选的
`background.png` / `background.jpg` / `background.jpeg`、可选的 `icons/` 文件，
以及可选的 `splash_logo.png` / `.jpg` / `.jpeg` / `.svg`。format 版本 1 包含 UI
颜色、应用内 icon、背景、组件圆角和 splash 屏。启动器 icon 和字体单独管理，主题包
不接受这两项。

可编辑的示例在
[Aurora](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/examples/aurora/manifest.toml)。
桌面端选择 **Install theme → Folder** 可以在开发过程中导入该目录：应用会校验文件
并复制进来，改动后重新选一次目录即可。要分发时，把目录内容打成 ZIP，使
`manifest.toml` 位于压缩包根目录，然后把扩展名改成 `.fsbt`。内置主题请以可编辑的
源目录形式放在 Git 里，不要提交生成出来的 `.fsbt`。
安装后的包会出现在 **Theme preset** 里。在该面板中，上/下键预览焦点主题但不保存
设置；回车（或点击条目）应用；Esc、点击外部或关闭面板都会恢复原样。预设项的值
只读；选择 **Custom** 可以挑选本地背景图，并编辑应用内 icon、圆角、不透明度和模糊。
之前的 Custom 图片和设置会在可用时恢复。

```toml
id = "example.amethyst"
name = "Amethyst"
modes = ["dark"]

# SVG icon、icon 颜色和 splash 都是 schema 2 的功能，所以这个包能被读取的
# 最低版本是 2。见 "Schema versions"。
[schema]
min = 2
max = 2

[colors]
mode = 2
seed = 0xFF880E4F

[colors.palette.dark]
primary = 0xFFC87FD0
surface = 0xFF141014

[icons.images]
"tab.server" = "icons/tab_server.svg"
"nav.settings" = "icons/nav_settings.png"

# 每个 icon 的颜色：ARGB 整数或 palette role 名。
[icons.colors]
"tab.server" = "primary"
"nav.settings" = 0xFFC87FD0

[background]
type = "image"
image = "background.png"
blur = 8

[splash]
color = "surface"
logo = "splash_logo.svg"
duration = 900
```

必填项只有 `id`、`name`、`modes` 和 `schema` 表。省略的字段取下表默认值；整张表
都可以省略。只写部分字段的表只覆盖写出的字段。显式的 0 会被保留；非法值会被拒绝，
不会被默认值替换。

| 字段 | 默认值 |
| --- | --- |
| `format` | `1` |
| `colors.mode` | `0`（跟随系统） |
| `colors.seed` | `0xFF880E4F` |
| `colors.systemColor` | `false` |
| `colors.palette.light`、`colors.palette.dark` | 空 |
| `icons.style` | `"classic"` |
| `icons.images` | 空 |
| `icons.colors` | 空（跟随 ambient icon color） |
| `splash` | 不存在（无 splash） |
| `background.type` | `"none"` |
| `background.opacity` | `0.18` |
| `background.blur` | `0` |
| `shapes.card`、`shapes.tile`、`shapes.button` | `12`、`8`、`10` |
| `components` | 空（沿用应用样式） |

Default 主题是 Dart const，圆角保持它自己的值（`13`、`9`、`30`）；上表这些默认值
适用于文件夹导入和 `.fsbt` 主题。


`modes` 必须声明 `["light"]`、`["dark"]` 或 `["light", "dark"]`。空列表、重复项和
未知模式都会被拒绝。只支持一种模式时会锁定应用的 ThemeMode，系统外观变化时也不变；
设置项里说明了要切换模式需要换一个主题。两种都支持时，System、Light、Dark 都可选。
`colors.mode` 是初始偏好：0（跟随系统）、1（light）、2（dark）。只支持一种模式时
该偏好被覆盖。AMOLED 是内置主题，两种模式都支持：light 用生成色，dark 用纯黑表面。
旧的 AMOLED 设置迁移为 Dark + AMOLED，Auto AMOLED 迁移为 System + AMOLED；AMOLED
不再是 ThemeMode 的选项。
`format` 是 ZIP manifest 结构的版本。`schema` 是该包支持的 theme UI schema 版本的
闭区间。应用目前支持 schema **v1–v2**，并在 **Install theme** 的帮助文字里显示这个
范围。安装器要求包的范围与应用的相交，加载已安装主题时会再检查一次。`schema.min`
和 `schema.max` 都是必填。
`seed` 和 palette 颜色是 ARGB 整数，支持十六进制 TOML 写法如 `0xFF61AFEF`。
`icons.style` 取 `classic` 或 `mingcute`，用于该包没有提供 image 的 icon。
`background.type` 取 `none`、`gradient` 或 `image`；type 不是 `image` 时不要写
`image`。不透明度 0–0.6，模糊 0–30，各圆角 0–40。
image 路径必须与上面这些固定名字一致。安装器会拒绝其他归档条目、重复路径、符号
链接、加密文件和路径穿越。它不认识的一级表会被拒绝，不会被忽略，所以拼错的
section 会报错，而不是变成一个什么都不做的设置。

## 编辑器用的 manifest schema

manifest 会对一份 JSON Schema 做校验，所以编辑时就能报出未知的表、未知的字段、
超出范围的值、不存在的 icon key，以及文件名与 key 不符的 icon：

```text
https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/docs/schemas/fsbt-manifest.schema.json
```

能读 Taplo schema directive 的 TOML 编辑器 —— Taplo、VS Code 的 Even Better TOML、
Tombi —— 从文件第一行挂上它，[示例](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/examples/aurora/manifest.toml)就是这么写的：

```toml
#:schema https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/docs/schemas/fsbt-manifest.schema.json
```

按文件名关联 schema 的编辑器则在各自的配置里填同一个 URL。通用的只有这个 directive。

schema 的严格程度与安装器一致，只有一条它表达不了：`icons.colors` 里的颜色需要在
`icons.images` 里有对应条目，这是跨两张表的检查。它报出的其他问题也都是安装会拒绝
的。schema 跟随最新的 schema 版本；声明 `min = 1` 的包照样能通过校验。

## Schema 版本

`schema.min` 是能读这个包的最旧应用版本，构建时就是拿它来比。这里不做迁移，读不了
就拒绝：范围与应用不相交的包不会被安装；已安装的包如果后来范围不再相交，就不会被
加载（显示为无法读取，其设置保持不动）。

Schema **2** 增加了 SVG icon、`icons.colors` 和 `splash` 表。用到其中任何一项的包
必须声明 `min = 2`，否则只认 schema 1 的构建会装上同样的字节并静默丢掉这些功能：
SVG icon 变成内置字形，颜色和 splash 都不会出现。`max = 2` 是当前上限；范围越过了
它，只要与应用相交仍然可以安装。

## Icons

`icons.images` 把 icon key 映射到 `icons/` 里承载它的文件。文件名必须是 key 里的点
换成下划线，扩展名两种都可：

```toml
[icons.images]
"tab.server" = "icons/tab_server.svg"
"nav.settings" = "icons/nav_settings.png"
```

PNG 最大 512 × 512 像素、256 KiB。SVG 没有可量的光栅尺寸，因此按文档校验：必须是
UTF-8，根元素必须是 `svg`，最大 256 KiB。DTD、实体声明、`<script>`、
`<foreignObject>`，以及任何指向文件外的写法 —— `http` 的 `href` 或 `url(http…)`
—— 都会被拒绝。被拒绝或缺失的 icon 会画该 key 的内置字形，而不是空框。

两种格式都只染一种颜色，所以图形里应当用 `currentColor` 表示要跟随颜色的部分。
没有 `icons.colors` 时，这个颜色就是 ambient icon color，也就是主题包无法自定义颜色
之前所有 icon 用的颜色。写了之后，每条覆盖一个 icon 的颜色：

```toml
[icons.colors]
"tab.server" = "primary"       # 任意 palette role，按 brightness 解析
"nav.settings" = 0xFFC87FD0    # 或 ARGB 整数
```

给一个包内没有 image 的 key 配颜色会被拒绝：那是一个最终什么都不显示的拼写错误。

## 调色板

`colors.palette.light` 和 `.dark` 接受下面全部 46 个未废弃的 ColorScheme role。
未指定的 role 取自 seed。未知和已废弃的 role 会被拒绝。palette 的值是 ARGB 整数。

```text
primary, onPrimary, primaryContainer, onPrimaryContainer
primaryFixed, primaryFixedDim, onPrimaryFixed, onPrimaryFixedVariant
secondary, onSecondary, secondaryContainer, onSecondaryContainer
secondaryFixed, secondaryFixedDim, onSecondaryFixed, onSecondaryFixedVariant
tertiary, onTertiary, tertiaryContainer, onTertiaryContainer
tertiaryFixed, tertiaryFixedDim, onTertiaryFixed, onTertiaryFixedVariant
error, onError, errorContainer, onErrorContainer
surface, onSurface, surfaceDim, surfaceBright
surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh
surfaceContainerHighest, onSurfaceVariant, outline, outlineVariant
shadow, scrim, inverseSurface, onInverseSurface
inversePrimary, surfaceTint
```

## 组件样式

公共值写在 `[components.card]`，按 brightness 区分的覆盖写在
`[components.light.card]` 或 `[components.dark.card]`。所有表和字段都是可选的。
缺失的字段保留应用原有样式；显式的 0 和 `false` 会被保留。组件的 `radius` 优先于
`[shapes]`。颜色可以是 ARGB 整数或任意 ColorScheme role 名（例如
`backgroundColor = "surfaceContainer"`），按最终 palette 解析。未知的组件名、字段、
状态和 role 名都会被拒绝。

| 组件 | 支持的字段 |
| --- | --- |
| `card` | `backgroundColor`, `radius`, `borderColor`, `borderWidth`, `elevation`, `shadowColor`, `surfaceTintColor`, `margin` |
| `tile` | `backgroundColor`, `selectedTileColor`, `textColor`, `iconColor`, `selectedColor`, `radius`, `borderColor`, `borderWidth`, `padding` |
| `button` | `backgroundColor`, `foregroundColor`, `overlayColor`, `radius`, `borderColor`, `borderWidth`, `elevation`, `shadowColor`, `surfaceTintColor`, `padding` |
| `input` | `filled`, `fillColor`, `radius`, `borderColor`, `borderWidth`, `focusedBorderColor`, `errorBorderColor`, `disabledBorderColor`, `padding` |
| `navigation` | `backgroundColor`, `indicatorColor`, `indicatorRadius`, `selectedIconColor`, `unselectedIconColor`, `selectedLabelColor`, `unselectedLabelColor`, `elevation` |
| `dialog` | `backgroundColor`, `radius`, `borderColor`, `borderWidth`, `elevation`, `shadowColor`, `surfaceTintColor`, `barrierColor`, `insetPadding` |
| `sheet` | `backgroundColor`, `radius`, `borderColor`, `borderWidth`, `elevation`, `shadowColor`, `surfaceTintColor`, `barrierColor`, `dragHandleColor` |

圆角 0–40，边框宽度 0–8，elevation 0–24。内边距（`padding`、`margin`、
`insetPadding`）是四个数 `[left, top, right, bottom]`，每个 0–64。数值必须有限。
`filled` 是布尔值。字体仍是单独的设置。

按钮状态表（`[components.button.hovered]`、`.pressed`、`.focused`、`.selected`、
`.disabled`）接受与按钮基础表相同的字段。状态表会在公共配置和 brightness 配置之间
合并。每个属性的优先级是 disabled > pressed > hovered > focused > selected > 基础值。
未指定的属性沿用既有的按钮主题和 Flutter 默认值。

这些样式作用于 Material 组件。自定义 NavigationRail 也使用 navigation 的颜色和
指示器形状；CardX 使用 card 的形状和 elevation；Input 使用 input 的边框和内边距；
SideBarTile 使用 tile 的颜色和边框，同时保留它的紧凑间距。Btn.elevated 使用 button
样式；紧凑的 Btn 行/列保留自身布局并使用主题圆角。单个 Widget 的显式覆盖仍然优先。
主题预览在内存中使用同一套设置；关闭选择器会恢复原样。

## Splash 屏

`splash` 在应用出第一帧的过程中用一层颜色和可选 logo 盖住界面，然后淡出。不写这张
表就没有 splash，否则每个包都会带上一个。

```toml
[splash]
color = "surface"          # 任意 palette role，或 ARGB 整数
logo = "splash_logo.svg"   # 可选，只能是压缩包根目录下的固定文件名
duration = 900             # 毫秒，100–3000，默认 600
```

logo 是压缩包根目录下名为 `splash_logo.png`、`splash_logo.jpg`、`splash_logo.jpeg`
或 `splash_logo.svg` 的单个文件，此处只能写文件名。PNG 或 JPEG 最大 2048 × 2048
像素、512 KiB；SVG 最大 512 KiB，并按 icon 同样的文档规则校验。它以 96 逻辑像素
居中绘制；只有 SVG 会被染色，光栅 logo 保留自身颜色。

`duration` 是 splash 淡出前停留的时长，它推迟的是启动过程，所以上限压得低。它只在
应用构建第一帧时读取一次：之后再换主题不会重放 splash，启动过程中选中的包也不会
播放自己的 splash。

能跟随主题的只有这一半。Dart 启动之前由操作系统绘制的内容 —— Android 的 window
background 或 iOS 的 launch storyboard —— 在打包时就已确定，只能跟随系统
brightness。

## Image key 与上限

支持的 icon key 是 `tab.<tab>` 和 `tab.<tab>.selected`，其中 `<tab>` 取 `server`、
`ssh`、`file`、`snippet`、`agent`、`benchmark`、`remoteDesktop`。navigation key 有
`nav.more`、`nav.settings`、`nav.tune`、`nav.privacy`、`nav.agent`、`nav.tabs`、
`nav.server`、`nav.sort`、`nav.terminal`、`nav.folder`、`nav.cloud`、`nav.snippet`、
`nav.inbox`、`nav.key`、`nav.info`、`nav.download`、`nav.desktop`。版本 1 中其他 key
会被拒绝。

压缩包和解压后总内容各限制 16 MiB。`manifest.toml` 限制 64 KiB。icon 限制
256 KiB，splash logo 512 KiB，背景 8 MiB、单边 8192 像素、总计 6400 万像素。安装器
在写入一个隔离的、按内容寻址的安装目录之前会检查每一张图 —— 解码 PNG 或 JPEG，或
把 SVG 当作文档读取。

## 主题商店

商店分两层读取。第一层是 **catalog**：一个 TOML 文件，逐条列出 repository，不涉及
具体主题和版本。第二层是 **repository**：一个 git 仓库，一个主题一个 TOML 文件。

应用自带的 catalog 是 `assets/catalog/repos.toml`，它的地址是
**Settings → Appearance → Theme store URL** 的默认值。该地址可编辑，因为一个不能
改指其他 catalog 的客户端只服务于一个发布方。catalog 有一份编译进应用，地址不响应
时使用，所以首次运行且无网络时也能列出官方 repository。

```toml
schema = 1
name = "ServerBox themes"

[[repo]]
url = "https://github.com/lollipopkit/serverbox-plugins"
```

最多 100 个 repository。repository 地址是 HTTPS，可以是 git 仓库 —— 按
`<address>/archive/HEAD.tar.gz` 拉取 —— 或直接是 tarball 地址。用 `HEAD` 而不是
分支名，因为仓库把哪个分支当作默认分支不该由应用来猜。

随应用提供的是
[`lollipopkit/serverbox-plugins`](https://github.com/lollipopkit/serverbox-plugins)，
官方主题和官方插件放在同一个树里。

### 主题 repository

`repo.toml` 声明该 repository 及其 schema；`themes/` 下一个主题一个文件，文件名取
主题的 `id`，路径与 id 不一致的文件会被拒绝。

```toml
schema = 1
name = "Somebody's themes"
```

```toml
# themes/amethyst.toml
id = "amethyst"
name = "Amethyst"
description = "A purple palette"
homepage = "https://example.org/amethyst"
license = "MIT"

[[version]]
version = "1.2.0"
schema_min = 1
schema_max = 1
url = "https://github.com/example/themes/releases/download/amethyst-1.2.0/amethyst.fsbt"
sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
size = 40960

[[version]]
version = "1.1.0"
schema_min = 1
schema_max = 1
path = "packages/amethyst-1.1.0.fsbt"
sha256 = "1111111111111111111111111111111111111111111111111111111111111111"
```

一个版本要么写 `url`（它自己的 release），要么写 `path`（repository 树里的一个
`.fsbt`）。`sha256` 是商店安装它的必要条件，`size` 用于在安装开始前显示开销。

`schema_min` 和 `schema_max` 是该包声明的 manifest schema 范围，一个 repository
借此同时服务不同年份的应用：**应用安装它能读的最新版本**，而不是列表里最新的版本。
只有过新版本的主题仍会列出，并注明这一点。包用到 schema 2 功能的版本写
`schema_min = 2`，因为包本身必须这样声明；写 1 会给旧应用一个装上后丢掉 icon、
颜色或 splash 的下载。

发布是每个主题每个版本一个 release，tag 为 `<id>-<version>`，附带 `.fsbt`。往应用
catalog 里加一个 repository，是向本仓库提一个新增 `[[repo]]` 条目的 pull request。

repository 可以在 `themes/` 旁边带一个 `plugins/` 部分。本构建读取 `themes/`，
不认识的部分跳过而不拒绝整个 repository，所以一个 repository 可以同时提供两者。

直接 URL 安装接受 HTTPS 的 `.fsbt` 链接，无需商店。安装器最多跟随三次 HTTPS
重定向，不发送凭据。catalog 限制 1 MiB；repository 树限制 16 MiB 压缩、64 MiB
解压、单个条目 8 MiB。
