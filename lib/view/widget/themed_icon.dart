import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/data/model/app/theme_style.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/package_image.dart';

/// A package image tinted like an icon, with the built-in glyph as fallback.
class ThemeIconAsset extends StatelessWidget {
  const ThemeIconAsset({
    required this.keyName,
    required this.fallback,
    super.key,
  });

  final String keyName;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      Stores.setting.appThemePackage.listenable(),
      ThemePackages.preview,
    ]),
    builder: (context, _) {
      final path = ThemePackages.activeIconPath(keyName);
      if (path == null) return fallback;
      final iconTheme = IconTheme.of(context);
      final scheme = Theme.of(context).colorScheme;
      return PackageImage(
        path: path,
        size: iconTheme.size ?? 24,
        // A package that names a color for this icon overrides the one the
        // ambient icon theme would give it; without one it follows that theme,
        // which is what every icon did before a package could say otherwise.
        color:
            ThemePackages.activeIconColor(keyName, scheme) ??
            iconTheme.color ??
            scheme.onSurface,
        fallback: fallback,
      );
    },
  );
}

/// Resolves shared navigation symbols through the active in-app icon family.
/// Symbols without a semantic counterpart keep their original glyph.
class ThemedIcon extends StatelessWidget {
  const ThemedIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  static final _mingcute = <IconData, IconData>{
    Icons.more_horiz: MingCute.more_2_line,
    Icons.settings_outlined: MingCute.settings_2_line,
    Icons.settings: MingCute.settings_2_fill,
    Icons.tune: MingCute.settings_2_line,
    Icons.privacy_tip_outlined: MingCute.shield_line,
    Icons.auto_awesome_outlined: MingCute.magic_2_line,
    Icons.tab_outlined: MingCute.dashboard_line,
    Icons.dns_outlined: MingCute.server_line,
    Icons.sort: MingCute.sort_ascending_line,
    Icons.terminal: MingCute.terminal_line,
    Icons.folder_outlined: MingCute.folder_line,
    Icons.cloud_outlined: MingCute.cloud_line,
    Icons.edit_note: MingCute.code_line,
    Icons.inbox_outlined: MingCute.inbox_line,
    Icons.key_outlined: MingCute.key_2_line,
    Icons.info_outline: MingCute.information_line,
    Icons.file_download_outlined: MingCute.download_line,
    Icons.desktop_windows_outlined: MingCute.computer_line,
  };

  static final _keys = <IconData, String>{
    Icons.more_horiz: 'nav.more',
    Icons.settings_outlined: 'nav.settings',
    Icons.settings: 'nav.settings',
    Icons.tune: 'nav.tune',
    Icons.privacy_tip_outlined: 'nav.privacy',
    Icons.auto_awesome_outlined: 'nav.agent',
    Icons.tab_outlined: 'nav.tabs',
    Icons.dns_outlined: 'nav.server',
    Icons.sort: 'nav.sort',
    Icons.terminal: 'nav.terminal',
    Icons.folder_outlined: 'nav.folder',
    Icons.cloud_outlined: 'nav.cloud',
    Icons.edit_note: 'nav.snippet',
    Icons.inbox_outlined: 'nav.inbox',
    Icons.key_outlined: 'nav.key',
    Icons.info_outline: 'nav.info',
    Icons.file_download_outlined: 'nav.download',
    Icons.desktop_windows_outlined: 'nav.desktop',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        Stores.setting.appIconStyle.listenable(),
        ThemePackages.preview,
      ]),
      builder: (context, _) {
        final selected =
            (ThemePackages.preview.value?.iconStyle ??
                    Stores.setting.appIconStyle.fetch()) ==
                IconStyle.mingcute
            ? (_mingcute[icon] ?? icon)
            : icon;
        final fallback = Icon(selected, size: size, color: color);
        final key = _keys[icon];
        if (key == null) return fallback;
        return IconTheme.merge(
          data: IconThemeData(size: size, color: color),
          child: ThemeIconAsset(keyName: key, fallback: fallback),
        );
      },
    );
  }
}
