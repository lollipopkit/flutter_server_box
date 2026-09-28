---
title: 主题包制作
description: 主题包格式、校验与发布
---

`.fsbt` 是 ZIP 压缩包。根目录包含 `manifest.toml`（UTF-8 编码的 TOML）、可选的
`background.png` / `background.jpg` / `background.jpeg`、可选的 `icons/` 文件，
以及可选的 `splash_logo.png` / `.jpg` / `.jpeg` / `.svg`。format 版本 1 包含 UI
颜色、应用内 icon、背景、组件圆角和 splash 屏。启动器 icon 和字体单独管理，主题包
不接受这两项。

主题包格式可参考
[Aurora](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/examples/aurora/manifest.toml)。
开发时可在桌面端选择 **Install theme → Folder**，导入主题源目录进行预览。应用会校验
并复制文件；修改后重新选择该目录即可重新加载。分发时，将目录内容打成 ZIP，确保
`manifest.toml` 位于压缩包根目录，再将扩展名设为 `.fsbt`。

内置主题的打包、加载与分发方式见[主题实现说明](/docs/zh/development/themes/)；面向
普通用户的主题选择与安装说明见[主题使用指南](/docs/zh/advanced/theme-packages/)。

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

Default 主题是 Dart const，继续使用自身的圆角值（`13`、`9`、`30`）。上表中的默认值
适用于从文件夹导入的主题和 `.fsbt` 主题。


`modes` 必须声明 `["light"]`、`["dark"]` 或 `["light", "dark"]`。空列表、重复项和
未知模式都会被拒绝。只支持一种模式时会锁定应用的 ThemeMode，系统外观变化时也不变；
设置项会提示用户：要切换模式，需要换用支持另一模式的主题。支持两种模式时，System、
Light 和 Dark 均可选。
`colors.mode` 是初始偏好：0（跟随系统）、1（light）、2（dark）。只支持一种模式时
该偏好被覆盖。AMOLED 是内置主题，两种模式都支持：light 用生成色，dark 用纯黑表面。
旧的 AMOLED 设置迁移为 Dark + AMOLED，Auto AMOLED 迁移为 System + AMOLED；AMOLED
不再是 ThemeMode 的选项。
`format` 表示 ZIP 中 manifest 结构的版本。`schema` 表示该包支持的 theme UI schema
版本范围，包含首尾。应用目前支持 schema **v1–v2**，并在 **Install theme** 的帮助文字
中显示该范围。安装器要求包与应用支持的范围有交集；加载已安装主题时也会再次检查。
`schema.min`
和 `schema.max` 都是必填。
`seed` 和 palette 颜色是 ARGB 整数，支持十六进制 TOML 写法如 `0xFF61AFEF`。
`icons.style` 取 `classic` 或 `mingcute`，用于该包没有提供 image 的 icon。
`background.type` 取 `none`、`gradient` 或 `image`；type 不是 `image` 时不要写
`image`。不透明度 0–0.6，模糊 0–30，各圆角 0–40。
image 路径必须使用上文列出的固定文件名。安装器会拒绝其他归档条目、重复路径、符号
链接、加密文件和路径穿越。未知的顶层表也会被拒绝，因此拼错的 section 会明确报错，
不会被静默忽略。

## 编辑器用的 manifest schema

manifest 可通过 JSON Schema 校验，编辑时即可发现未知表或字段、超出范围的值、无效的
icon key，以及文件名与 key 不匹配的 icon：

```text
https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/docs/schemas/fsbt-manifest.schema.json
```

支持 Taplo schema directive 的 TOML 编辑器（Taplo、VS Code 的 Even Better TOML、
Tombi）会从文件第一行读取 schema。[示例](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/examples/aurora/manifest.toml)
也使用了这种写法：

```toml
#:schema https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/docs/schemas/fsbt-manifest.schema.json
```

通过文件名关联 schema 的编辑器，则需在各自配置中填写同一个 URL。只有该 directive 可
跨编辑器通用。

schema 与安装器同样严格，只有一条规则无法表达：`icons.colors` 中的 key 必须在
`icons.images` 中有对应条目，因为这项检查涉及两张表。schema 报出的其他问题也都会被
安装器拒绝。schema 始终描述最新版本，因此声明 `min = 1` 的包也能通过校验。schema
的定义依据及校验方式见[主题](/docs/zh/development/themes/#解析器与编辑器-schema)。

## Schema 版本

`schema.min` 表示能够读取该包的最旧应用 schema 版本，安装时会据此检查兼容性。应用
不会迁移不兼容的包，而是直接拒绝：支持范围与应用不相交的包无法安装；已安装的包若
之后变得不兼容，也不会加载（界面会标记为无法读取，且保留其设置）。

Schema **2** 增加了 SVG icon、`icons.colors` 和 `splash` 表。使用其中任一功能的包都
必须声明 `min = 2`。否则仅支持 schema 1 的构建仍会安装这些文件，却会静默丢弃相关功能：
SVG icon 会退回内置字形，指定颜色和 splash 也不会生效。当前上限为 `max = 2`；即使
包的范围高于该值，只要与应用支持的范围有交集，仍可安装。

## Icons

`icons.images` 把 icon key 映射到 `icons/` 里承载它的文件。文件名必须是 key 里的点
换成下划线，扩展名两种都可：

```toml
[icons.images]
"tab.server" = "icons/tab_server.svg"
"nav.settings" = "icons/nav_settings.png"
```

PNG 最大为 512 × 512 像素、256 KiB。SVG 不含光栅尺寸，因此改为校验文档结构：必须是
UTF-8，根元素必须是 `svg`，最大 256 KiB。DTD、实体声明、`<script>`、`<style>`、
`<foreignObject>`，以及任何引用外部文件的写法（非本文档片段的 `href` 或 `url(…)`）
都会被拒绝。icon 缺失或校验失败时，会显示该 key 对应的内置字形。

两种格式的 icon 都只使用单一颜色。需要随颜色变化的图形部分应使用 `currentColor`。
未设置 `icons.colors` 时，icon 使用 ambient icon color，与主题包支持自定义颜色之前的行为
一致。设置该表后，每项可为一个 icon 指定颜色：

```toml
[icons.colors]
"tab.server" = "primary"       # 任意 palette role，按 brightness 解析
"nav.settings" = 0xFFC87FD0    # 或 ARGB 整数
```

如果为包中没有对应 image 的 key 指定颜色，安装器会拒绝该包，避免无效配置被静默接受。

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

圆角范围为 0–40，边框宽度为 0–8，elevation 为 0–24。内边距（`padding`、`margin`、
`insetPadding`）是四个数 `[left, top, right, bottom]`，每个 0–64。数值必须有限。
`filled` 是布尔值。字体仍是单独的设置。

按钮状态表（`[components.button.hovered]`、`.pressed`、`.focused`、`.selected`、
`.disabled`）接受与按钮基础表相同的字段。状态表会在公共配置和 brightness 配置之间
合并。每个属性的优先级是 disabled > pressed > hovered > focused > selected > 基础值。
未指定的属性沿用既有的按钮主题和 Flutter 默认值。

这些样式适用于 Material 组件。自定义 NavigationRail 也使用 navigation 的颜色和
指示器形状；CardX 使用 card 的形状和 elevation；Input 使用 input 的边框和内边距；
SideBarTile 使用 tile 的颜色和边框，同时保留它的紧凑间距。Btn.elevated 使用 button
样式；紧凑的 Btn 行/列保留自身布局并使用主题圆角。单个 Widget 的显式覆盖仍然优先。
主题预览在内存中使用同一套设置；关闭选择器会恢复原样。

## Splash 屏

应用启动并绘制首帧时，`splash` 会显示一层背景色和可选 logo，随后淡出。省略该表即可
禁用 splash，避免每个主题包都默认显示启动画面。

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

`duration` 表示 splash 淡出前的显示时长，会延后应用启动，因此上限设得较低。该值只在
应用绘制首帧时读取一次：之后切换主题不会再次显示 splash，启动过程中选中的主题包也
不会显示自己的 splash。

主题只能控制应用启动后的这一层。Dart 启动前由操作系统绘制的内容（Android 的 window
background 或 iOS 的 launch storyboard）在构建应用时确定，只能随系统 brightness 变化。

## Image key 与上限

支持的 icon key 是 `tab.<tab>` 和 `tab.<tab>.selected`，其中 `<tab>` 取 `server`、
`ssh`、`file`、`snippet`、`agent`、`benchmark`、`remoteDesktop`、`virt`。navigation key 有
`nav.more`、`nav.settings`、`nav.tune`、`nav.privacy`、`nav.agent`、`nav.tabs`、
`nav.server`、`nav.sort`、`nav.terminal`、`nav.folder`、`nav.cloud`、`nav.snippet`、
`nav.inbox`、`nav.key`、`nav.info`、`nav.download`、`nav.desktop`。版本 1 中其他 key
会被拒绝。

压缩包和解压后总内容各限制 16 MiB。`manifest.toml` 限制 64 KiB。icon 限制
256 KiB，splash logo 512 KiB，背景 8 MiB、单边 8192 像素、总计 6400 万像素。安装器
写入隔离的内容寻址安装目录前，安装器会检查每张图片：解码 PNG/JPEG，并按文档结构
解析 SVG。

## 主题商店

商店分两层读取。第一层是 **catalog**，即逐条列出 repository 的 TOML 文件，不包含
具体主题或版本。第二层是 **repository**，即存放主题 TOML 文件的 git 仓库，每个主题
对应一个文件。

在 **Settings → Appearance → Theme store** 可打开主题商店页面。页面将 catalog 中的
主题与本机已安装的主题合并为一个列表，同一主题只显示一项。点按未安装的主题可安装并
应用；点按已安装的主题可应用。每项右侧的按钮会根据状态提供安装或移除操作。移除当前
主题后，应用会切回默认主题。

主题列表会保留到下次启动，因此页面打开时可立即显示上次读取的内容。标题栏下方会注明
列表来自哪些 repository，以及读取时间。点按该行旁边的刷新按钮可重新读取 catalog。
当前版本无法读取的主题仍会列出并标注状态，方便确认该主题是否存在。


```toml
schema = 1
name = "ServerBox themes"

[[repo]]
url = "https://github.com/lollipopkit/serverbox-plugins"
```

repository URL 必须使用 HTTPS，可以指向 git 仓库或 tarball。对于 git 仓库，应用从
`<address>/archive/HEAD.tar.gz` 获取内容，以使用仓库的默认分支而不假设分支名称。

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

每个版本必须提供 `url`（指向该版本的 release）或 `path`（指向 repository 树中的
`.fsbt` 文件）。商店安装时必须校验 `sha256`；`size` 用于在安装前显示下载大小。

`schema_min` 和 `schema_max` 表示主题包支持的 manifest schema 范围。这样一个 repository
可以同时服务不同版本的应用：**应用会安装自己支持的最新主题版本**，不一定是列表中的
最新版本。若主题只有当前应用无法读取的版本，仍会显示并注明原因。使用 schema 2 功能的
版本必须设置 `schema_min = 2`；若误设为 1，旧版应用可能安装后静默丢弃 icon、颜色或
splash。

每个主题版本都通过独立的 release 发布，tag 格式为 `<id>-<version>`，并附带 `.fsbt`
文件。若要将 repository 加入应用 catalog，请向本仓库提交包含新增 `[[repo]]` 条目的
pull request。

repository 可在 `themes/` 旁边包含 `plugins/` 目录。本构建只读取主题，因此会跳过该
目录，不会因此拒绝整个 repository。

直接 URL 安装接受 HTTPS 的 `.fsbt` 链接，无需商店。安装器最多跟随三次 HTTPS
重定向，不发送凭据。catalog 和 repository 树各自的大小上限见
[主题](/docs/zh/development/themes/#主题商店)。

## 主题来源

ServerBox 把下面这些 VS Code 主题的 UI 调色板改编到 Material 的表面、选中态、卡片
和按钮上。这些改编与 VS Code 扩展包无关。字体和终端/编辑器配色仍是单独的设置。
Midnight 和 AMOLED 是 ServerBox 原创的调色板。AMOLED 在 dark 下使用纯黑表面、在
light 下使用生成色，因此支持 System 外观。

入选依据是 Marketplace 上独立配色主题的安装量，已排除 icon 主题和随语言工具分发的
主题。GitHub Theme、One Dark Pro 和 Dracula 是这次比较中排名最前的三个。GitHub
Dark 使用 GitHub Theme 的 dark 调色板。必要时会调整次要文字颜色，使正常文字的对比度
不低于 4.5:1。

<details>
<summary>上游署名</summary>

**One Dark Pro**

Source: [One Dark Pro](https://github.com/Binaryify/OneDark-Pro)

The MIT License (MIT)

Copyright (c) 2013-2022 Binaryify

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

**GitHub Theme**

Source: [GitHub Theme](https://github.com/primer/github-vscode-theme)

MIT License

Copyright (c) 2020 Primer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

**Dracula**

Source: [Dracula](https://github.com/dracula/visual-studio-code)

The MIT License (MIT)

Copyright (c) 2016 Dracula Theme

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

</details>
