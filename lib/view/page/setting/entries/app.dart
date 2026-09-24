part of '../entry.dart';

/// Where an install takes its package from.
///
/// A folder is a directory on this device, which only a desktop can pick, so it
/// is offered behind a platform test rather than refused afterwards.
enum _ThemeInstallSource { file, folder, url }

extension _App on _AppSettingsPageState {
  void _showInvalidDialog() {
    context.showRoundDialog(title: libL10n.fail, child: Text(libL10n.invalid));
  }

  List<SettingsGroup> _buildApp() {
    return [
      SettingsGroup(libL10n.general, [_buildLocale(), _buildCollapseUI()]),
      SettingsGroup(libL10n.update, [_buildCheckUpdate(), _buildBeta()]),
      // Everything about the machine the app happens to be on, which is why
      // every row in it is behind a platform test. It is also where the rows
      // that used to be behind a tile called "More" ended up: a group with a
      // name is what that tile was standing in for.
      SettingsGroup(libL10n.system, [
        if (_bioAuthAvail == true) _buildBioAuth(),
        if (isMobile) _buildWakeLock(),
        if (isAndroid) _buildBgRun(),
        if (isDesktop) _buildHideTitleBar(),
        if (DmgNotice.applies) _buildDmgNotice(),
        // Debug only, which is where it was moved to while these rows were
        // flat. Naming the group does not put it back in a release build.
        if (kDebugMode) _buildEditRawSettings(),
      ]),
    ];
  }

  /// What the app looks like, in two groups.
  ///
  /// Theme and font were two pages, each holding a group the other's name
  /// would have covered: the theme page opened on a group called "Appearance"
  /// and the font page was one group called "Font". The page is the appearance
  /// and the groups are the two halves of it — which is also what puts the
  /// font beside the theme it is part of, rather than a tap away.
  List<SettingsGroup> _buildAppearance() => [
    SettingsGroup(libL10n.theme, [
      _buildThemeMode(),
      _buildAppColor(),
      _buildThemePreset(),
      _buildThemeInstall(),
      _buildThemeStore(),
      if (_setting.appThemePreset.fetch() == ThemePackages.customPreset) ...[
        _buildAppIcons(),
        _buildCorners(),
        _buildAppBackground(),
        _buildAppBackgroundOpacity(),
        _buildAppBackgroundBlur(),
      ],
    ]),
    SettingsGroup(libL10n.font, [
      _buildAppFontFamilies(),
      _buildAppFontImport(),
    ]),
  ];

  void _saveCustomTheme() => ThemePackages.saveCustomTheme();

  void _markCustomTheme() {
    if (_setting.appThemePreset.fetch() != ThemePackages.customPreset ||
        _setting.appBackgroundStyle.fetch() != BackgroundStyle.image ||
        _setting.appBackgroundPath.fetch().isEmpty) {
      return;
    }
    _setting.appThemePreset.put(ThemePackages.customPreset);
    _saveCustomTheme();
  }

  SettingsRow _buildThemePreset() {
    final label = l10n.appearancePreset;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: Text(label),
        trailing: _setting.appThemePreset.listenable().listenVal(
          (preset) => Text(
            BuiltinTheme.fromId(preset)?.label ??
                switch (ThemePackages.installationIdOf(preset)) {
                  final installationId? =>
                    ThemePackages.installed(installationId)?.name ??
                        libL10n.invalid,
                  _ => libL10n.custom,
                },
          ),
        ),
        onTap: () async {
          final names = ThemePackages.installedPresetNames();
          final original = _setting.appThemePreset.fetch();
          var open = true;
          var request = 0;
          Future<void> preview(String value) async {
            final current = ++request;
            try {
              final theme = value == original
                  ? null
                  : value == ThemePackages.customPreset
                  ? _readCustomTheme()
                  : switch (ThemePackages.installationIdOf(value)) {
                      final installationId? => ThemePackages.installed(
                        installationId,
                      ),
                      _ => await ThemePackages.loadBuiltin(
                        BuiltinTheme.fromId(value)!,
                      ),
                    };
              if (open && current == request) {
                ThemePackages.preview.value = theme;
              }
            } catch (_) {
              if (open && current == request) {
                ThemePackages.preview.value = null;
              }
            }
          }

          String? preset;
          try {
            preset = await showRowsSheet<String>(
              context,
              // The choices and nothing above them. The catalog used to be a
              // row at the top of this sheet as well, which is a way in that
              // leaves the sheet for a page and then comes back to a preset
              // list that no longer matches what was installed there — the
              // store is a row of its own in the appearance page instead.
              rows: (ctx) => [
                for (final value in [
                  ...BuiltinTheme.values.map((theme) => theme.id),
                  ThemePackages.customPreset,
                  ...names.keys,
                ])
                  SheetChoiceTile(
                    title:
                        BuiltinTheme.fromId(value)?.label ??
                        (value == ThemePackages.customPreset
                            ? libL10n.custom
                            : names[value] ?? libL10n.invalid),
                    selected: value == original,
                    autofocus: value == original,
                    onFocusChange: (focused) {
                      if (focused) unawaited(preview(value));
                    },
                    onTap: () => Navigator.of(ctx).pop(value),
                  ),
              ],
            );
          } finally {
            open = false;
            ThemePackages.preview.value = null;
          }
          if (!mounted) return;
          if (preset == null) return;
          if (preset == ThemePackages.customPreset) {
            if (_setting.appThemePreset.fetch() != ThemePackages.customPreset) {
              await _restoreCustomTheme();
            }
            return;
          }
          if (ThemePackages.installationIdOf(preset)
              case final installationId?) {
            final package = ThemePackages.installed(installationId);
            if (package == null) {
              Toast.error(l10n.appearanceInvalidTheme);
              return;
            }
            _applyTheme(package);
            return;
          }
          await _applyThemePreset(BuiltinTheme.fromId(preset)!);
        },
      ),
      keywords:
          '${BuiltinTheme.values.map((theme) => theme.label).join(' ')} custom theme',
    );
  }

  /// Opens the catalog, which is reached from its own row in the appearance
  /// page and from nowhere else.
  void _openThemeStore() => ThemeStorePage.route.go(context);

  void _applyTheme(ThemePackage package, {String? preset}) {
    ThemePackages.apply(package, preset: preset);
    setStateSafe(() {});
    RNodes.app.notify();
  }

  SettingsRow _buildThemeInstall() {
    final label = l10n.appearanceThemeInstall;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.install_desktop_outlined),
        title: TipText(
          label,
          '${l10n.appearanceThemeSchemaRange}: ${ThemePackages.supportedSchemaRange}',
        ),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () async {
          final source = await context
              .showPickSingleDialog<_ThemeInstallSource>(
            title: label,
            items: [
              _ThemeInstallSource.file,
              if (isDesktop) _ThemeInstallSource.folder,
              _ThemeInstallSource.url,
            ],
            display: (source) => switch (source) {
              _ThemeInstallSource.file => libL10n.file,
              _ThemeInstallSource.folder => libL10n.folder,
              _ThemeInstallSource.url => 'URL',
            },
          );
          if (source == null || !mounted) return;
          switch (source) {
            case _ThemeInstallSource.file:
              final picked = await FilePicker.pickFile(
                type: FileType.custom,
                allowedExtensions: ['fsbt'],
              );
              if (picked == null || !mounted) return;
              if (await picked.length() > ThemePackages.maxPackageBytes) {
                Toast.error(l10n.appearanceInvalidTheme);
                return;
              }
              await _completeThemeInstall(
                () async => ThemePackages.install(await picked.readAsBytes()),
              );
            case _ThemeInstallSource.folder:
              final folder = await FilePicker.getDirectoryPath(
                dialogTitle: label,
              );
              if (folder == null || !mounted) return;
              await _completeThemeInstall(
                () => ThemePackages.installFolder(folder),
              );
            case _ThemeInstallSource.url:
              final url = await _promptAppText(
                label,
                hint: 'https://…/theme.fsbt',
              );
              if (url == null || url.isEmpty || !mounted) return;
              await _completeThemeInstall(() => ThemePackages.installUrl(url));
          }
        },
      ),
      keywords: 'fsbt theme folder URL import schema version',
    );
  }

  SettingsRow _buildThemeStore() {
    final label = l10n.appearanceThemeStore;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.storefront_outlined),
        title: Text(label),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: _openThemeStore,
      ),
      keywords: 'theme catalog store repository',
    );
  }

  Future<void> _completeThemeInstall(
    Future<ThemePackage> Function() install,
  ) async {
    final (package, error) = await context.showLoadingDialog<ThemePackage>(
      fn: install,
    );
    if (!mounted) return;
    if (error != null || package == null) {
      Loggers.app.warning('Theme installation failed: ${error.runtimeType}');
      Toast.error(l10n.appearanceInvalidTheme);
      return;
    }
    _applyTheme(package);
    Toast.show(libL10n.success);
  }

  Future<String?> _promptAppText(
    String title, {
    String initial = '',
    String? hint,
  }) async {
    final controller = TextEditingController(text: initial);
    try {
      return (await context.showRoundDialog<String>(
        title: title,
        child: Input(
          controller: controller,
          autoFocus: true,
          hint: hint,
          onSubmitted: (_) => context.popDialog(controller.text.trim()),
        ),
        actions: [
          Btn.cancel(),
          Btn.ok(onTap: () => context.popDialog(controller.text.trim())),
        ],
      ))?.trim();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _applyThemePreset(BuiltinTheme preset) async {
    try {
      final theme = await ThemePackages.loadBuiltin(preset);
      if (!mounted) return;
      _applyTheme(theme, preset: preset.id);
    } catch (error, stack) {
      Loggers.app.warning('Could not load built-in theme', error, stack);
      if (mounted) Toast.error(l10n.appearanceInvalidTheme);
    }
  }

  ThemePackage _readCustomTheme() {
    final path = _setting.appCustomBackgroundPath.fetch();
    if (!_isOwnedAppBackground(path) || !File(path).existsSync()) {
      throw const FormatException('Custom background is unavailable');
    }
    final data =
        jsonDecode(_setting.appCustomTheme.fetch()) as Map<String, dynamic>;
    final mode = (data['mode'] as num).toInt();
    final seed = (data['seed'] as num).toInt();
    final systemColor = data['systemColor'] as bool;
    final icons = IconStyle.parse(data['icons']);
    final opacity = (data['opacity'] as num).toDouble();
    final blur = (data['blur'] as num).toDouble();
    final card = (data['card'] as num).toDouble();
    final tile = (data['tile'] as num).toDouble();
    final button = (data['button'] as num).toDouble();
    if (mode < 0 || mode > 2 || seed < 0 || seed > 0xffffffff || icons == null) {
      throw const FormatException('Invalid custom theme');
    }
    return ThemePackage(
      installationId: '',
      // The theme this app makes up is the one the preset names, so the two
      // spellings are one value.
      id: ThemePackages.customPreset,
      name: libL10n.custom,
      schemaMin: 1,
      schemaMax: 1,
      mode: mode,
      modes: const {ThemeMode.light, ThemeMode.dark},
      seed: seed,
      systemColor: systemColor,
      paletteLight: const {},
      paletteDark: const {},
      iconStyle: icons,
      // A custom theme is the user's own background and radii, so it carries no
      // package images and no splash: both of those are a package's.
      iconFiles: const {},
      backgroundStyle: BackgroundStyle.image,
      backgroundFile: path,
      directory: '',
      opacity: opacity.clamp(0.0, 0.6),
      blur: blur.clamp(0.0, 30.0),
      cardRadius: card.clamp(0.0, 40.0),
      tileRadius: tile.clamp(0.0, 40.0),
      buttonRadius: button.clamp(0.0, 40.0),
    );
  }

  Future<void> _restoreCustomTheme() async {
    try {
      final theme = _readCustomTheme();
      _applyTheme(theme, preset: ThemePackages.customPreset);
      _setting.appThemePaletteEnabled.put(false);
    } catch (_) {
      await _pickAppBackground();
    }
  }

  SettingsRow _buildBioAuth() {
    return SettingsRow(
      libL10n.bioAuth,
      PlatformPublicSettings.buildBioAuthRows,
    );
  }

  SettingsRow _buildBgRun() {
    final label = l10n.bgRun;
    return SettingsRow(
      label,
      () => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: TipText(label, l10n.bgRunTip),
            trailing: StoreSwitch(prop: Stores.setting.bgRun),
          ),
          _buildBgRunPermission(),
        ],
      ),
      keywords: l10n.bgRunTip,
    );
  }

  /// Says so when the switch above cannot do what it says.
  ///
  /// Running in the background means holding a foreground service, and a
  /// foreground service means a notification — so an app whose notifications
  /// are turned off is frozen the moment it leaves the screen, and every
  /// connection dies with nothing on screen explaining it (#1287). Shown only
  /// in that case: a row saying "this is fine" on every other device is noise.
  Widget _buildBgRunPermission() {
    return FutureWidget(
      future: MethodChans.notificationsAllowed(),
      loading: UIs.placeholder,
      error: (_, _) => UIs.placeholder,
      success: (allowed) {
        if (allowed != false) return UIs.placeholder;
        return ListTile(
          leading: Icon(Icons.notifications_off, color: UIs.primaryColor),
          title: TipText(libL10n.permission, l10n.bgRunNeedsNotification),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            await MethodChans.openNotificationSettings();
            // Read again on the way back: the point of sending someone there
            // is that they change it, and a row still saying it is off would
            // make them wonder whether it took.
            setStateSafe(() {});
          },
        );
      },
    );
  }

  /// The App Store build's one standing entry about the DMG build. The line in
  /// the update dialog is asked to go away and does; this one stays, so there
  /// is somewhere to read the whole thing afterwards.
  SettingsRow _buildDmgNotice() {
    final label = l10n.macDmgTitle;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.apple_fill),
        title: Text(label),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => DmgNotice.show(context),
      ),
    );
  }

  SettingsRow _buildCheckUpdate() {
    final label = libL10n.checkUpdate;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.update),
        title: Text(label),
        subtitle: ValBuilder(
          listenable: AppUpdateIface.newestBuild,
          builder: (val) {
            String display;
            if (val != null) {
              if (val > BuildData.build) {
                display = libL10n.versionHasUpdate(val);
              } else {
                display = libL10n.versionUpdated(BuildData.build);
              }
            } else {
              display = libL10n.versionUnknownUpdate(BuildData.build);
            }
            return Text(display, style: UIs.textGrey);
          },
        ),
        onTap: () => Fns.throttle(
          () => AppUpdateIface.doUpdate(
            context: context,
            build: BuildData.build,
            githubReleasesUrl: Urls.githubReleasesApi,
            storeUrl: Urls.appStore,
            force: BuildMode.isDebug,
            noticeBuilder: (ctx) => DmgNotice.forUpdate(
              ctx,
              build: AppUpdateIface.newestBuild.value ?? BuildData.build,
            ),
          ),
        ),
        trailing: StoreSwitch(prop: _setting.autoCheckAppUpdate),
      ),
      // The version is on this row, so it is what somebody typing one is
      // looking for.
      keywords: 'v${BuildData.build}',
    );
  }

  SettingsRow _buildUpdateInterval() {
    final label = l10n.updateServerStatusInterval;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: Text(label),
        onTap: () async {
          final val = await context.showPickSingleDialog(
            title: libL10n.setting,
            items: List.generate(10, (idx) => idx == 1 ? null : idx),
            initial: _setting.serverStatusUpdateInterval.fetch(),
            display: (p0) => p0 == 0 ? libL10n.manual : '$p0 ${l10n.second}',
          );
          if (val != null) {
            _setting.serverStatusUpdateInterval.put(val);
          }
        },
        trailing: ValBuilder(
          listenable: _setting.serverStatusUpdateInterval.listenable(),
          builder: (val) => Text('$val ${l10n.second}', style: UIs.text15),
        ),
      ),
    );
  }

  SettingsRow _buildAppColor() {
    final label = libL10n.primaryColorSeed;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.colorize),
        title: Text(label),
        trailing: _setting.colorSeed.listenable().listenVal((_) {
          return ClipOval(
            child: Container(color: UIs.primaryColor, height: 23, width: 23),
          );
        }),
        onTap: _onTapAppColor,
      ),
    );
  }

  /// What each icon family is called. Neither is translated: one is the app's
  /// own set and the other is the one it borrows.
  String _iconStyleLabel(IconStyle style) => switch (style) {
    IconStyle.classic => 'Classic',
    IconStyle.mingcute => 'MingCute',
  };

  SettingsRow _buildAppIcons() {
    final label = l10n.appearanceIcons;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.widgets_outlined),
        title: Text(label),
        trailing: _setting.appIconStyle.listenable().listenVal(
          (style) => Text(_iconStyleLabel(style)),
        ),
        onTap: () async {
          final style = await context.showPickSingleDialog<IconStyle>(
            title: label,
            items: IconStyle.values,
            initial: _setting.appIconStyle.fetch(),
            display: _iconStyleLabel,
          );
          if (style == null) return;
          _setting.appIconStyle.put(style);
          _setting.appThemePackage.put('');
          _markCustomTheme();
          RNodes.app.notify();
        },
      ),
      keywords: 'icons MingCute Classic',
    );
  }

  SettingsRow _buildCorners() {
    final label = l10n.appearanceCorners;
    return SettingsRow(
      label,
      () => ExpansionTile(
        key: const PageStorageKey('theme-corners'),
        leading: const Icon(Icons.crop_square),
        title: Text(label),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          _buildCornerRow(
            l10n.appearanceCardCorners,
            Icons.crop_square,
            _setting.appCardRadius,
          ).build(),
          _buildCornerRow(
            l10n.appearanceTileCorners,
            Icons.view_list_outlined,
            _setting.appTileRadius,
          ).build(),
          _buildCornerRow(
            l10n.appearanceButtonCorners,
            Icons.smart_button_outlined,
            _setting.appButtonRadius,
          ).build(),
        ],
      ),
      keywords:
          '${l10n.appearanceCardCorners} ${l10n.appearanceTileCorners} '
          '${l10n.appearanceButtonCorners} card tile button radius',
    );
  }

  SettingsRow _buildCornerRow(
    String label,
    IconData icon,
    SqlitePropDefault<double> property,
  ) {
    return SettingsRow(
      label,
      () => ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: property.listenable().listenVal(
          (radius) => Text('${radius.round()}'),
        ),
        onTap: () async {
          final radius = await context.showPickSingleDialog<double>(
            title: label,
            items: [0.0, 6.0, 9.0, 13.0, 20.0, 30.0, 40.0],
            initial: property.fetch(),
            display: (value) => '${value.round()}',
          );
          if (radius == null) return;
          property.put(radius);
          _markCustomTheme();
          RNodes.app.notify();
        },
      ),
      keywords: 'card tile button radius',
    );
  }

  SettingsRow _buildAppBackground() {
    final label = libL10n.background;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.wallpaper_outlined),
        title: Text(label),
        trailing: Text(libL10n.image),
        onTap: _pickAppBackground,
      ),
    );
  }

  Future<void> _pickAppBackground() async {
    final path = await Pfs.pickFilePath();
    if (path == null) return;
    var stage = 'read';
    try {
      final source = File(path);
      if (await source.length() > 8 * 1024 * 1024) {
        throw const FormatException('Image exceeds 8 MB');
      }
      stage = 'decode';
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          if (descriptor.width > 8192 ||
              descriptor.height > 8192 ||
              descriptor.width * descriptor.height > 64 * 1024 * 1024) {
            throw const FormatException('Image resolution exceeds limit');
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
      stage = 'copy';
      final dest = File(
        Paths.img.joinPath(
          'app_bg_${DateTime.now().microsecondsSinceEpoch}.img',
        ),
      );
      await source.copy(dest.path);
      if (!mounted) {
        await dest.delete();
        return;
      }
      final oldPath = _setting.appBackgroundPath.fetch();
      _setting.appThemePackage.put('');
      _setting.appThemePaletteEnabled.put(false);
      _setting.appBackgroundPath.put(dest.path);
      _setting.appBackgroundStyle.put(BackgroundStyle.image);
      _setting.appThemePreset.put(ThemePackages.customPreset);
      _markCustomTheme();
      setStateSafe(() {});
      RNodes.app.notify();
      unawaited(_deleteOwnedAppBackground(oldPath));
    } catch (error, stack) {
      Loggers.app.warning('Import background failed at $stage', error, stack);
      if (mounted) Toast.error(libL10n.invalid);
    }
  }

  Future<void> _deleteOwnedAppBackground(String path) async {
    if (!_isOwnedAppBackground(path)) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // The selected image may already have been removed outside the app.
    }
  }

  bool _isOwnedAppBackground(String path) =>
      path.isNotEmpty &&
      File(path).parent.path == Paths.img &&
      File(path).uri.pathSegments.last.startsWith('app_bg_');

  SettingsRow _buildAppBackgroundOpacity() {
    final label = libL10n.opacity;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.opacity),
        title: Text(label),
        trailing: _setting.appBackgroundOpacity.listenable().listenVal(
          (opacity) => Text('${(opacity * 100).round()}%'),
        ),
        onTap: () async {
          final opacity = await context.showPickSingleDialog<double>(
            title: label,
            items: [0, 0.1, 0.18, 0.3, 0.45, 0.6],
            initial: _setting.appBackgroundOpacity.fetch(),
            display: (value) => '${(value * 100).round()}%',
          );
          if (opacity == null) return;
          _setting.appBackgroundOpacity.put(opacity);
          _markCustomTheme();
          RNodes.app.notify();
        },
      ),
    );
  }

  SettingsRow _buildAppBackgroundBlur() {
    final label = libL10n.blurRadius;
    return SettingsRow(
      label,
      () => _setting.appBackgroundStyle.listenable().listenVal(
        (style) => ListTile(
          leading: const Icon(Icons.blur_on),
          title: Text(label),
          enabled:
              style == BackgroundStyle.image &&
              _setting.appBackgroundPath.fetch().isNotEmpty,
          trailing: _setting.appBackgroundBlur.listenable().listenVal(
            (radius) => Text('${radius.round()}'),
          ),
          onTap: () async {
            var radius = _setting.appBackgroundBlur.fetch().clamp(0.0, 30.0);
            final selected = await context.showRoundDialog<double>(
              title: label,
              child: StatefulBuilder(
                builder: (context, setState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${radius.round()}'),
                    Slider(
                      value: radius,
                      min: 0,
                      max: 30,
                      divisions: 30,
                      label: '${radius.round()}',
                      onChanged: (value) => setState(() => radius = value),
                    ),
                  ],
                ),
              ),
              actions: [
                Btn.cancel(),
                Btn.ok(onTap: () => context.popDialog(radius)),
              ],
            );
            if (selected == null) return;
            _setting.appBackgroundBlur.put(selected);
            _markCustomTheme();
            RNodes.app.notify();
          },
        ),
      ),
      keywords: 'background blur radius',
    );
  }

  SettingsRow _buildAppFontFamilies() {
    final label = l10n.appearanceFontFamilies;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.font_download_outlined),
        title: TipText(label, l10n.appearanceFontFamiliesTip),
        trailing: _setting.appFontFamilies.listenable().listenVal(
          (_) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              AppFont.families.isEmpty
                  ? libL10n.system
                  : AppFont.families.join(' → '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        onTap: () async {
          final controller = TextEditingController(
            text: AppFont.families.join('\n'),
          );
          try {
            final value = await context.showRoundDialog<String>(
              title: label,
              child: TextField(
                controller: controller,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: 'Inter\nNoto Sans\nArial',
                  helperText: l10n.appearanceFontFamiliesTip,
                ),
              ),
              actions: [
                Btn.cancel(),
                Btn.ok(onTap: () => context.popDialog(controller.text)),
              ],
            );
            if (value == null || !mounted) return;
            AppFont.saveFamilies(value.split(RegExp(r'[\r\n]+')));
            RNodes.app.notify();
          } finally {
            controller.dispose();
          }
        },
      ),
      keywords: 'global font fallback families',
    );
  }

  SettingsRow _buildAppFontImport() {
    final label = l10n.appearanceFontImport;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.file_download_outlined),
        title: Text(label),
        trailing: _setting.appImportedFontName.listenable().listenVal(
          (name) => name.isEmpty
              ? const Icon(Icons.keyboard_arrow_right)
              : IconButton(
                  tooltip: libL10n.delete,
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await AppFont.removeImported();
                    RNodes.app.notify();
                  },
                ),
        ),
        onTap: () async {
          final picked = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: ['ttf', 'otf'],
          );
          if (picked == null || !mounted) return;
          final path = picked.path;
          if (path == null || await picked.length() > AppFont.maxBytes) {
            Toast.error(libL10n.invalid);
            return;
          }
          final suggested = picked.name.replaceFirst(
            RegExp(r'\.(ttf|otf)$', caseSensitive: false),
            '',
          );
          final name = await _promptAppText(
            label,
            initial: suggested,
            hint: suggested,
          );
          if (name == null || name.isEmpty || !mounted) return;
          final (_, error) = await context.showLoadingDialog<void>(
            fn: () => AppFont.importFile(path, name),
          );
          if (!mounted) return;
          if (error != null) {
            Loggers.app.warning('Import app font failed: ${error.runtimeType}');
            Toast.error(libL10n.invalid);
            return;
          }
          RNodes.app.notify();
          Toast.show(libL10n.success);
        },
      ),
      keywords: 'TTF OTF font file import',
    );
  }

  void _onTapAppColor() {
    withTextFieldController((ctrl) async {
      ctrl.text = Color(_setting.colorSeed.fetch()).toHex;
      await context.showRoundDialog(
        title: libL10n.primaryColorSeed,
        child: StatefulBuilder(
          builder: (context, setState) {
            final children = <Widget>[
              if (!isIOS)
                DynamicColorBuilder(
                  builder: (light, dark) {
                    final supported = light != null || dark != null;
                    if (!supported) {
                      if (!_setting.useSystemPrimaryColor.fetch()) {
                        _setting.useSystemPrimaryColor.put(false);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {});
                        });
                      }
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      title: Text(libL10n.followSystem),
                      trailing: StoreSwitch(
                        prop: _setting.useSystemPrimaryColor,
                        callback: (_) {
                          _setting.appThemePaletteEnabled.put(false);
                          if (_setting.appThemePreset.fetch() ==
                              ThemePackages.customPreset) {
                            _saveCustomTheme();
                          }
                          RNodes.app.notify();
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
            ];
            if (!_setting.useSystemPrimaryColor.fetch()) {
              children.add(
                ColorPicker(
                  color: Color(_setting.colorSeed.fetch()),
                  onColorChanged: (c) => ctrl.text = c.toHex,
                ),
              );
            }
            return Column(mainAxisSize: MainAxisSize.min, children: children);
          },
        ),
        actions: [
          Btn.cancel(),
          Btn.ok(onTap: () => _onSaveColor(ctrl.text)),
        ],
      );
    });
  }

  void _onSaveColor(String s) {
    final color = s.fromColorHex;

    if (color == null) {
      Toast.error(libL10n.fail);
      return;
    }

    // Save the color seed to settings
    _setting.colorSeed.put(color.value255);
    _setting.appThemePaletteEnabled.put(false);
    if (_setting.appThemePreset.fetch() == ThemePackages.customPreset) {
      _saveCustomTheme();
    }

    // Only update UIs colors if we're not in system mode
    if (!_setting.useSystemPrimaryColor.fetch()) {
      UIs.primaryColor = color;
      UIs.colorSeed = color;
    }

    RNodes.app.notify();
    // `popDialog`: reached from the colour dialog's OK, with the settings
    // page's `context`.
    context.popDialog();
  }

  SettingsRow _buildMaxRetry() {
    final label = l10n.maxRetryCount;
    return SettingsRow(
      label,
      () => ValBuilder(
        listenable: _setting.maxRetryCount.listenable(),
        builder: (val) => ListTile(
          leading: const Icon(Icons.replay),
          title: Text(label),
          onTap: () async {
            final selected = await context.showPickSingleDialog(
              title: label,
              items: List.generate(10, (index) => index),
              display: (p0) => '$p0 ${l10n.times}',
              initial: val,
            );
            if (selected != null) {
              _setting.maxRetryCount.put(selected);
            }
          },
          trailing: Text('$val ${l10n.times}', style: UIs.text15),
        ),
      ),
    );
  }

  SettingsRow _buildThemeMode() {
    final label = libL10n.themeMode;
    final locked = ThemePackages.activeTheme?.lockedMode;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.moon_stars_fill),
        title: Text(label),
        subtitle: locked == null
            ? null
            : Text(
                l10n.appearanceThemeModeLocked(
                  _buildThemeModeStr(locked.index),
                ),
              ),
        enabled: locked == null,
        onTap: locked != null
            ? null
            : () async {
                final selected = await context.showPickSingleDialog(
                  title: label,
                  items: List.generate(
                    ThemeMode.values.length,
                    (index) => index,
                  ),
                  display: (p0) => _buildThemeModeStr(p0),
                  initial: _setting.themeMode.fetch(),
                );
                if (selected != null) {
                  _setting.themeMode.put(selected);
                  if (_setting.appThemePreset.fetch() ==
                      ThemePackages.customPreset) {
                    _saveCustomTheme();
                  }
                  RNodes.app.notify();
                }
              },
        trailing: ValBuilder(
          listenable: _setting.themeMode.listenable(),
          builder: (val) =>
              Text(_buildThemeModeStr(locked?.index ?? val), style: UIs.text15),
        ),
      ),
      keywords: '${libL10n.dark} ${libL10n.bright}',
    );
  }

  String _buildThemeModeStr(int n) {
    switch (n) {
      case 1:
        return libL10n.bright;
      case 2:
        return libL10n.dark;
      default:
        return libL10n.auto;
    }
  }

  SettingsRow _buildLocale() {
    final label = libL10n.language;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(IonIcons.language),
        title: Text(label),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: label,
            items: AppLocalizations.supportedLocales,
            display: (p0) => p0.nativeName,
            initial: _setting.locale.fetch().toLocale,
          );
          if (selected != null) {
            _setting.locale.put(selected.code);
            // No `pop`: the picker has already closed — that is what `await`
            // returning a selection means — so popping here closed the settings
            // page behind it. `notify` is what makes the new language take
            // effect; nothing has to be dismissed for that.
            RNodes.app.notify();
          }
        },
        trailing: ListenBuilder(
          listenable: _setting.locale.listenable(),
          builder: () => Text(context.localeNativeName, style: UIs.text15),
        ),
      ),
    );
  }

  /// Its own page rather than two rows under the app's own settings, because
  /// what it decides is not the same kind of thing as the rows it sat among.
  ///
  /// A page can also be reached — from the intro that first asks the question,
  /// from a release note, from an answer to someone asking what is collected —
  /// and a row buried in a collapsed tile cannot.
  List<SettingsGroup> _buildPrivacy() {
    return [
      // Only where a report could actually be sent. A control that cannot do
      // anything is worse than one that is not offered, and a build with no
      // DSN in it can do nothing here. See [DiagnosticsUpload].
      //
      // Uncarded: the picker is a list of cards already.
      if (DiagnosticsUpload.availableInBuild)
        SettingsGroup(l10n.crashCollect, [
          _buildDiagnosticsUpload(),
        ], carded: false),
      // Not behind `availableInBuild` — a build with no upload endpoint is
      // exactly the one where handing the log over by hand is the only way a
      // crash gets reported at all. Absent when nothing crashed: a row reading
      // "no crash report" would be on the page for the whole life of every
      // healthy install, while a row that appears is itself the news.
      if (_savedCrashReport != null)
        SettingsGroup(libL10n.log, [_buildLastCrashReport()]),
      SettingsGroup(l10n.privacy, [
        // The policy describes what is kept on the device as well as what is
        // sent, so it has something to say in a build that uploads nothing.
        _buildPrivacyPolicy(),
        // Last, after everything about what leaves the device. It is the one
        // control here that acts on this moment instead — who can read the
        // screen.
        ?PlatformPublicSettings.privacyBlur?.row,
      ]),
    ];
  }

  /// Where the choice made on the intro page can be revisited.
  ///
  /// The same widget the intro puts the question with, so the answer reads the
  /// same in both places. It replaced a row whose trailing text named the
  /// current level and whose tap opened a picker of three bare labels: the
  /// sentence saying what a level actually sends existed only on the intro,
  /// which is the one screen a user sees once and cannot go back to.
  SettingsRow _buildDiagnosticsUpload() {
    return SettingsRow(
      l10n.crashCollect,
      () => DiagnosticsLevelPicker(
        // Applied now rather than at the next launch: turning it down has to
        // take the sink out immediately, not eventually.
        onPicked: () => unawaited(DiagnosticsUpload.sync()),
      ),
    );
  }

  /// The previous run's log, when there is one.
  ///
  /// Whether one exists is a file on disk, read once when the page opens —
  /// see [_AppSettingsPageState.initState]. Read here through a builder it
  /// flickered out and back on every unrelated rebuild, and the group it is in
  /// could not know whether to exist at all.
  SettingsRow _buildLastCrashReport() {
    final label = l10n.crashReportTitle;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: Text(label),
        subtitle: Text(l10n.crashLastRunFailed, style: UIs.textGrey),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final report = _savedCrashReport;
          if (report == null) return;
          final kept = await CrashReportDialog.show(context, report);
          // The row goes when the report does.
          if (kept) return;
          _savedCrashReport = null;
          refresh();
        },
      ),
    );
  }

  /// Beside the level, not inside the picker.
  ///
  /// The dialog that picks a level is a list of three options and has nowhere
  /// to put a link; and the policy is worth reaching without first opening the
  /// control that changes a setting.
  SettingsRow _buildPrivacyPolicy() {
    final label = l10n.privacyPolicy;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.policy_outlined),
        title: Text(label),
        trailing: const Icon(Icons.open_in_new, size: 17),
        onTap: Urls.privacyPolicy.launchUrl,
      ),
    );
  }

  SettingsRow _buildBeta() {
    final label = l10n.preReleaseUpdates;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.science_outlined),
        title: Text(label),
        trailing: StoreSwitch(prop: _setting.betaTest),
      ),
    );
  }

  SettingsRow _buildWakeLock() {
    final label = l10n.wakeLock;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.lock_fill),
        title: Text(label),
        trailing: StoreSwitch(prop: _setting.generalWakeLock),
      ),
    );
  }

  SettingsRow _buildCollapseUI() {
    final label = 'UI ${libL10n.fold}';
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.unfold_less),
        title: TipText(label, l10n.collapseUITip),
        trailing: StoreSwitch(prop: _setting.collapseUIDefault),
      ),
      keywords: l10n.collapseUITip,
    );
  }

  SettingsRow _buildHideTitleBar() {
    final label = libL10n.hideTitleBar;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.web_asset),
        title: Text(label),
        trailing: StoreSwitch(
          prop: _setting.hideTitleBar,
          callback: (value) async {
            await SystemUIs.updateTitleBarStyle(hideTitleBar: value);
          },
        ),
      ),
    );
  }

  SettingsRow _buildEditRawSettings() {
    const label = '(Dev) Edit raw json';
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.data_object),
        title: const Text(label),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: _editRawSettings,
      ),
    );
  }

  Future<void> _editRawSettings() async {
    final rawMap = Stores.setting.getAllMap(includeInternalKeys: true);
    final map = Map<String, Object?>.from(rawMap);
    final initialKeys = Set<String>.from(map.keys);
    Map<String, Object?> mapForEditor = map;
    String? encryptedKey;
    String? passwordUsed;

    Future<String?> resolvePassword() async {
      final saved = await _setting.backupPassword.read();
      if (saved?.isNotEmpty == true) return saved;
      final backupPwd = await SecureStoreProps.bakPwd.read();
      if (backupPwd?.isNotEmpty == true) return backupPwd;
      final controller = TextEditingController();
      try {
        final result = await context.showRoundDialog<String>(
          title: libL10n.pwd,
          child: Input(
            controller: controller,
            label: libL10n.pwd,
            obscureText: true,
            onSubmitted: (_) => context.popDialog(controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => context.popDialog(null),
              child: Text(libL10n.cancel),
            ),
            TextButton(
              onPressed: () => context.popDialog(controller.text.trim()),
              child: Text(libL10n.ok),
            ),
          ],
        );
        return result?.trim();
      } finally {
        controller.dispose();
      }
    }

    for (final entry in map.entries) {
      final value = entry.value;
      if (value is String && Cryptor.isEncrypted(value)) {
        final password = await resolvePassword();
        if (password == null || password.isEmpty) {
          Toast.show(libL10n.cancel);
          return;
        }
        try {
          final decrypted = Cryptor.decrypt(value, password);
          final decoded = json.decode(decrypted);
          if (decoded is Map<String, dynamic>) {
            mapForEditor = Map<String, Object?>.from(decoded);
            encryptedKey = entry.key;
            passwordUsed = password;
            break;
          } else {
            _showInvalidDialog();
            return;
          }
        } catch (e, stack) {
          final msg =
              e.toString().contains('Failed to decrypt') ||
                  e.toString().contains('incorrect password')
              ? l10n.backupPasswordWrong
              : '${libL10n.error}:\n$e';
          context.showRoundDialog(title: libL10n.fail, child: Text(msg));
          Loggers.app.warning('Decrypt raw settings failed', e, stack);
          return;
        }
      }
    }

    void onSave(EditorPageRet ret) {
      if (ret.typ != EditorPageRetType.text) {
        _showInvalidDialog();
        return;
      }
      try {
        final newSettings = json.decode(ret.val) as Map<String, dynamic>;
        if (encryptedKey != null) {
          final pwd = passwordUsed;
          if (pwd == null || pwd.isEmpty) {
            _showInvalidDialog();
            return;
          }
          final encrypted = Cryptor.encrypt(json.encode(newSettings), pwd);
          // Not stamping `lastUpdateTs`, which is what going straight to the
          // box used to do.
          //
          // TODO: decide whether that was intentional. Editing the raw settings
          // is a user edit, so leaving the timestamps alone means sync will not
          // carry it to another device until something else is changed.
          Stores.setting.set(
            encryptedKey,
            encrypted,
            updateLastUpdateTsOnSet: false,
          );
        } else {
          // One transaction, as `Backup.merge` does: this rewrites the whole
          // settings store, and half of an edit is not a state to leave behind.
          SqliteStore.transact(() {
            for (final entry in newSettings.entries) {
              final value = entry.value;
              // A key set to null means "clear this". Skipping it instead left
              // the previous value in place, and the key being present kept it
              // out of `removedKeys` below too — so the edit reported success and
              // changed nothing.
              if (value == null) {
                Stores.setting.remove(
                  entry.key,
                  updateLastUpdateTsOnRemove: false,
                );
                continue;
              }
              Stores.setting.set(
                entry.key,
                value as Object,
                updateLastUpdateTsOnSet: false,
              );
            }
            final newKeys = newSettings.keys.toSet();
            // Internal keys are shown by the editor (it reads with
            // `includeInternalKeys: true`) but are not the user's to delete: one
            // of them records that the Hive import already ran, and dropping it
            // makes the next launch copy the retained boxes back over everything.
            final removedKeys = initialKeys.where(
              (e) => !newKeys.contains(e) && !Stores.setting.isInternalKey(e),
            );
            for (final key in removedKeys) {
              Stores.setting.remove(key, updateLastUpdateTsOnRemove: false);
            }
          });
        }
      } catch (e, trace) {
        context.showRoundDialog(
          title: libL10n.error,
          child: Text('${libL10n.save}:\n$e'),
        );
        Loggers.app.warning('Update json settings failed', e, trace);
      }
    }

    /// Encode [map] to String with indent `\t`
    final text = jsonIndentEncoder.convert(mapForEditor);
    final editorFont = _setting.editorFontFamily.fetch();
    await EditorPage.route.go(
      context,
      args: EditorPageArgs(
        text: text,
        lang: ProgLang.json,
        title: libL10n.setting,
        onSave: onSave,
        closeAfterSave: _setting.closeAfterSave.fetch(),
        softWrap: _setting.editorSoftWrap.fetch(),
        enableHighlight: _setting.editorHighlight.fetch(),
        lightTheme: HighlightTheme.fromThemeMapKey(
          _setting.editorTheme.fetch(),
        ),
        darkTheme: HighlightTheme.fromThemeMapKey(
          _setting.editorDarkTheme.fetch(),
        ),
        fontFamily: editorFont.isEmpty ? null : editorFont,
      ),
    );
  }
}
