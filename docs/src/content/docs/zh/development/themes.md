---
title: 主题
description: 内置主题如何打包、加载与分发
---

本页介绍主题在本仓库中的实现与分发方式。编写主题、安装主题，以及发布你自己的
repository 见[主题包](/docs/zh/advanced/theme-packages/)；内置主题改编自哪些上游
调色板见[主题来源](/docs/zh/advanced/theme-packages/#主题来源)。

## 内置主题

`BuiltinTheme`（`lib/data/model/app/builtin_theme.dart`）列出本构建随附的包，以及
每个包在选择器里的标签。`Default` 是 Dart const，不读取任何 asset。其余五个是
`assets/themes/<id>/` 下的源目录，各含一个 `manifest.toml`，并在 `pubspec.yaml`
中注册。

内置目录走的是与导入目录、`.fsbt` 压缩包同一个安装器，所以随应用提供的主题不会
比安装来的主题多出任何字段。这些目录以源码形式入库，Flutter 直接打包；不为它们
提交任何压缩包或其他二进制 asset。

新增一个除了目录本身之外是两处改动：`pubspec.yaml` 里一行，以及一个
`BuiltinTheme` case 用于选择器标签。

## 加载

`BuiltinThemeLoader`（`lib/core/service/theme_package.dart`）按需加载。它用
`_loaded` 保存已返回的结果，用 `_pending` 保存进行中的加载，因此同一个主题的两个
请求共用一次解析，失败也不会被缓存，可以重试。

打开选择器不加载任何主题文件。一个目录在被选中时读取，或在启动时它是保存的选择时
读取。内置 asset 与用户安装的主题使用各自独立的运行时缓存，不出现在用户安装列表
中。

## 解析器与编辑器 schema

manifest 的语法由三个文件定义：`theme_package.dart`（顶层表、归档条目、schema
范围）、`theme_components.dart`（组件字段、状态、以及各个数值范围），以及
`theme_palette.dart`（未废弃的 ColorScheme role）。`docs/schemas/fsbt-manifest.schema.json`
为编辑器镜像这些定义，所以它是照这三个文件写的，而不是照本文档写的。

它的严格程度与安装器一致，只有一条表达不了：`icons.colors` 里的颜色需要在
`icons.images` 里有对应条目，这是跨两张表的检查，JSON Schema 没有对应的写法。

所有入库的 manifest —— 内置目录和 `docs/examples/aurora/` —— 都由 CI 的 `docs`
任务按 schema 校验；schema 本身由 `test/unit/theme_schema_test.dart` 对着解析器
对齐：编辑器给出的字段、枚举和取值范围，就是安装时接受的。

## 主题商店

`ThemeRepo`（`lib/core/service/theme_repo.dart`）读取两个层级：repository 的
catalog，以及某个 repository 的目录树。`assets/catalog/repos.toml` 是下限 ——
首次运行且无网络时提供的内容 —— `Urls.themeCatalog` 则是该地址有响应时应用改读的
地址。

repository 地址是 HTTPS，解析到一个 tarball。git 仓库按
`<address>/archive/HEAD.tar.gz` 拉取，因为仓库把哪个分支当作默认分支不该由应用来
猜。`ThemePackages.download` 拒绝带凭据的 URL，最多跟随三次重定向，每次都用新地址
重新校验 HTTPS。repository 不接受明文 HTTP：它决定装上的是哪些字节。

上限写在 `ThemeRepo` —— catalog 100 个 repository、1 MiB，repository 树 16 MiB
压缩、64 MiB 解压、单个条目 8 MiB。本构建不认识的 section 会被跳过，而不是让整个
repository 失败，于是一棵树可以同时带 `themes/` 和 `plugins/`，服务本应用和插件
两项功能。

商店页面在 `lib/view/page/theme_store/`。列表在两次启动之间保留于
`SettingStore.themeStoreCache`，以 `ThemeStore.toJson()` 写入，`updateLastModified:
false`，并列入 `SettingStore.deviceLocalKeys` —— 一份 catalog 曾提供什么的缓存，既
不是要同步的编辑，也不是要还原到另一台设备的东西。缓存中的条目不带 repository 文件
（`ThemeStoreItem.index` 为 null），所以树内的版本会重新向它的 repository 取 tarball；
两种情况的 digest 校验相同。

## 官方主题

`lollipopkit/serverbox-plugins` 用 `themes/` 存放官方主题，一个主题一个源目录加一个
listing，旁边是 `plugins/`。

`scripts/publish-themes.sh <id> <version>` 发布一个版本。它从 manifest 里读出 id 和
`[schema]` 范围，使 listing 记录的是包自己声明的内容；用 `zip` 打包目录，`-X` 避免
把每台机器不同的文件属性写进压缩包；算出 digest 和大小；创建 tag 为
`<id>-<version>` 的 release，asset 为 `<tag>.fsbt`；最后向 listing 追加一个
`[[version]]` 块。

它强制的两个顺序都是出问题时不报错的那些。release 先于指向它的 listing 上传，因为
指向 404 的 listing 对每个读者都是坏的。已记录但 digest 不同的版本会被拒绝而不是
重新发布，因为一个不再标识特定字节的版本号会让这里其余所有检查失去意义。
