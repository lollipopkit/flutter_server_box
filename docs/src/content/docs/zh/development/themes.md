---
title: 主题
description: 内置主题如何打包、加载与分发
---

本页介绍本仓库内置主题的实现与分发方式。主题包格式和发布流程见
[主题包制作指南](/docs/zh/development/theme-authoring/)；普通用户的主题选择与安装说明见
[主题使用指南](/docs/zh/advanced/theme-packages/)。上游调色板来源及其署名也列在制作指南中。

## 内置主题

`BuiltinTheme`（`lib/data/model/app/builtin_theme.dart`）列出本构建内置的主题及其在
选择器中的标签，只包含离线也必须可用的主题。`Default` 是 Dart const，不读取 asset，
它在选择器中的标签已本地化（fl_lib 的 `defaultLabel`）。AMOLED 是旧版 AMOLED 主题模式
迁移的目标，源目录位于 `assets/themes/amoled/`，其中包含 `manifest.toml`，并在
`pubspec.yaml` 中注册。其他官方主题都在主题商店中（见[官方主题](#官方主题)）；如果保存的
预设指向本构建已不再内置的主题，会回退到 Default（`ThemePackages.reconcileSelection`）。

内置目录与导入目录和 `.fsbt` 压缩包共用同一个安装器，因此内置主题和已安装主题支持
相同的字段。这些目录以源码形式入库，由 Flutter 直接打包；仓库不提交对应的压缩包或
其他二进制 asset。

新的官方主题应放进主题商店，而不是内置。只有离线也必须可用的主题才需要内置：创建
目录，在 `pubspec.yaml` 中注册，并添加一个 `BuiltinTheme` case。

## 加载

`BuiltinThemeLoader`（`lib/core/service/theme_package.dart`）按需加载主题。`_loaded`
保存已完成的结果，`_pending` 跟踪正在进行的加载，因此对同一主题的并发请求共用一次
解析。失败结果不会缓存，可以重试。

打开选择器时不会加载主题文件。目录只会在主题被选中时读取；如果启动时恢复的是已保存
主题，也会在启动阶段读取。内置 asset 使用独立于用户安装主题的运行时缓存，也不会显示在
用户安装列表中。

## 解析器与编辑器 schema

manifest 语法由三个文件定义：`theme_package.dart`（顶层表、归档条目和 schema
范围）、`theme_components.dart`（组件字段、状态和数值范围），以及
`theme_palette.dart`（未废弃的 ColorScheme role）。编辑器使用的
`docs/schemas/fsbt-manifest.schema.json` 与这些定义保持一致，因此 schema 以这三个文件为
依据，而不是以本文档为依据。

schema 与安装器同样严格，只有一条规则无法表达：`icons.colors` 中的 key 必须在
`icons.images` 中有对应条目。这项检查涉及两张表，JSON Schema 无法描述。

CI 的 `docs` 任务会按 schema 校验所有入库的 manifest，包括内置目录和
`docs/examples/aurora/`。`test/unit/theme_schema_test.dart` 则检查 schema 与解析器是否
一致，确保编辑器提供的字段、枚举和取值范围都与安装器接受的内容相符。

## 主题商店

`ThemeRepo`（`lib/core/service/theme_repo.dart`）先读取 repository catalog，再读取各
repository 的目录树。首次运行且无网络时，应用使用 `assets/catalog/repos.toml`；如果
`Urls.themeCatalog` 有响应，则改用该地址提供的 catalog。

repository URL 必须使用 HTTPS，并指向 tarball。对于 git 仓库，应用从
`<address>/archive/HEAD.tar.gz` 获取文件，以使用仓库的默认分支而无需假设其名称。
`ThemePackages.download` 会拒绝包含凭据的 URL，最多跟随三次重定向，并逐一确认目标仍
使用 HTTPS。repository URL 不接受明文 HTTP，因为它决定了要安装的内容。

`ThemeRepo` 设定了以下上限：每个 catalog 最多包含 100 个 repository，大小不超过
1 MiB；每棵 repository 树压缩后不超过 16 MiB、解压后不超过 64 MiB；单个条目不超过
8 MiB。应用会跳过不认识的 section，不会因此拒绝整个 repository，因此同一目录树可以
同时包含供本应用使用的 `themes/` 和供插件功能使用的 `plugins/`。

商店页面位于 `lib/view/page/theme_store/`。主题列表保存在
`SettingStore.themeStoreCache`，供下次启动时读取；数据通过 `ThemeStore.toJson()` 写入，
并设置 `updateLastModified: false`。该 key 列在 `SettingStore.deviceLocalKeys` 中，
因为它只是 catalog 内容缓存，不是需要同步或恢复到其他设备的用户数据。缓存条目不包含
repository 文件（`ThemeStoreItem.index` 为 null），所以安装目录树中的版本时，应用会
重新从 repository 获取 tarball。无论来源如何，都会校验 digest。

## 官方主题

官方主题放在本仓库的 `store/` 中：`store/repo.toml`，以及每个主题的 listing
`store/themes/<id>.toml` 和与之并列的源目录 `store/themes/<id>/`。
`test/unit/theme_store_tree_test.dart` 按商店的方式读取该目录，读取器会丢弃的 listing
会让测试失败，而不是从商店里消失。

应用不会下载整个仓库。官网构建时运行 `scripts/store-tarball.sh`，用 `git archive` 把
`HEAD` 的 `store/` 写成 `public/store.tar.gz`，catalog 列出的地址是
`https://serverbox.lollipopkit.com/store.tar.gz`。对 `store/` 的改动在官网部署后生效：
Cloudflare Pages 项目在 `store/`、`website/` 和 `docs/` 有改动时都会重新构建。同一次构建
也会在官网上列出这些主题（`website/store-data.js`）。
使用 `git archive` 而不是 `tar`，是因为 macOS `tar` 会写入读取器拒绝的二进制 xattr 记录。

`scripts/publish-themes.py` 一次发布所有自最新记录版本以来有变化的主题。它以 `store/`
作为主题 repository，调用 serverbox-theme skill 的 `scripts/publish.py`；第三方作者在
自己的仓库里发布主题时用的也是这个脚本。只有官方主题在本仓库发布。它打包每个
目录，把包的 digest 与 listing 中最新版本的 digest 比较：相同表示没有变化，跳过该主题；
不同则发布新版本，默认递增补丁号（`--bump minor|major` 递增其他部分，`<id>=<version>`
指定确切版本，尚无版本的主题从 1.0.0 开始）。`--dry-run` 只显示计划；在参数中写明 id
可以只处理这些主题。

能用 digest 判断是否变化，是因为打包结果是确定的：条目按名称排序，使用固定的时间戳和
权限，并且不压缩（stored），因此字节只取决于文件内容，与 checkout 的修改时间和机器上的
zlib 版本无关。

所有新包以 `<id>-<version>.fsbt` 为名一起上传到本仓库 tag 为 `themes` 的 release，
然后向各 listing 追加带 digest 和大小的 `[[version]]` 块，之后提交 listing。所有包放在
同一个 release 中：应用的更新检查读取本仓库的 release 列表，tag 中没有构建号的 release
会被跳过；如果每个主题版本各发一个 release，应用自己的 release 会被挤出第一页。该
release 是 pre-release，以 `--latest=false` 创建，永远不会成为本仓库的 Latest：GitHub
不会把 pre-release 标为 Latest，因此 Latest 始终是应用的 release；脚本在上传任何内容之前
也会检查这一点。

脚本会遵守两项顺序与完整性规则：先上传包，再更新引用它的 listing，避免 listing 指向
不存在的 asset；从不覆盖已上传的 asset（中断的运行留下的 asset，只有字节相同时才会被
接受），也从不让同一个版本号对应第二份内容。
