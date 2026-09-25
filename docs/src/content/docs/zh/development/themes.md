---
title: 主题
description: 内置主题如何打包、加载与分发
---

本页介绍本仓库内置主题的实现与分发方式。主题包格式和发布流程见
[主题包制作指南](/docs/zh/development/theme-authoring/)；普通用户的主题选择与安装说明见
[主题使用指南](/docs/zh/advanced/theme-packages/)。上游调色板来源及其署名也列在制作指南中。

## 内置主题

`BuiltinTheme`（`lib/data/model/app/builtin_theme.dart`）列出本构建内置的主题及其在
选择器中的标签。`Default` 是 Dart const，不读取 asset。其余五个主题各有一个位于
`assets/themes/<id>/` 的源目录，目录中包含 `manifest.toml`，并在 `pubspec.yaml` 中注册。

内置目录与导入目录和 `.fsbt` 压缩包共用同一个安装器，因此内置主题和已安装主题支持
相同的字段。这些目录以源码形式入库，由 Flutter 直接打包；仓库不提交对应的压缩包或
其他二进制 asset。

新增主题时，除主题目录外，还需在 `pubspec.yaml` 中注册目录，并添加一个带选择器标签的
`BuiltinTheme` case。

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

`lollipopkit/serverbox-plugins` 在 `themes/` 中存放官方主题，每个主题各有一个源目录和
一个 listing；`plugins/` 与该目录并列。

`scripts/publish-themes.sh <id> <version>` 用于发布一个版本。脚本从 manifest 读取 id 和
`[schema]` 范围，确保 listing 记录包自身声明的内容；再用 `zip` 打包目录。`-X` 选项会
排除机器相关的文件属性。随后脚本计算 digest 和大小，创建 tag 为 `<id>-<version>` 的
release，并将 `<tag>.fsbt` 作为 asset，最后向 listing 追加一个 `[[version]]` 块。

脚本会强制执行两项顺序与完整性规则：先上传 release，再更新引用它的 listing，避免
listing 指向不存在的 asset；如果已记录版本的 digest 不同，则拒绝重新发布，确保同一个
版本号始终对应相同内容。
