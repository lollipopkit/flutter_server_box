import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/app/theme_style.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';

/// Where the store themes this app ships are: one `<id>.fsbt` each, the exact
/// bytes the store publishes for that version.
const themeBundledDir = 'assets/store_themes/';

/// The copy of the theme catalog compiled in, read when its address does not
/// answer.
const themeCatalogAsset = 'assets/catalog/repos.toml';

/// What the shared theme code (`package:fl_lib/theme.dart`) is told about this
/// app: set once at launch by [initThemeHost], before anything reads a theme.
void initThemeHost() => ThemeHost.init(
  ThemeHost(
    store: () => Stores.setting,
    appName: BuildData.name,
    icons: ThemeIcons(
      tabs: [for (final tab in AppTab.values) tab.name],
      symbols: _symbols,
    ),
    bundledThemesDir: themeBundledDir,
    catalogUrl: Urls.themeCatalog,
    catalogAsset: themeCatalogAsset,
    packageDocUrl: Urls.themePackageDoc,
    preview: const ThemePreviewContent(
      body: _previewBody,
      actions: [
        ('nav.sort', Icons.sort),
        ('nav.settings', Icons.settings_outlined),
      ],
      tabs: [
        ('server', Icons.dns_outlined),
        ('ssh', Icons.terminal),
        ('file', Icons.folder_outlined),
        ('agent', Icons.auto_awesome_outlined),
      ],
    ),
  ),
);

/// The glyphs [ThemedIcon] swaps: the key a package replaces each with, and
/// its MingCute counterpart. Every [ThemeNavIcon] is here, so the keys a
/// package may use in this app are the tabs' and these.
final _symbols = <IconData, ThemeSymbol>{
  Icons.more_horiz: ThemeSymbol(ThemeNavIcon.more.iconKey, mingcute: MingCute.more_1_line),
  Icons.more_vert: ThemeSymbol(ThemeNavIcon.more.iconKey, mingcute: MingCute.more_2_line),
  Icons.settings_outlined: ThemeSymbol(ThemeNavIcon.settings.iconKey, mingcute: MingCute.settings_2_line),
  Icons.settings: ThemeSymbol(ThemeNavIcon.settings.iconKey, mingcute: MingCute.settings_2_fill),
  Icons.tune: ThemeSymbol(ThemeNavIcon.tune.iconKey, mingcute: MingCute.settings_2_line),
  Icons.privacy_tip_outlined: ThemeSymbol(ThemeNavIcon.privacy.iconKey, mingcute: MingCute.shield_line),
  Icons.auto_awesome_outlined: ThemeSymbol(ThemeNavIcon.agent.iconKey, mingcute: MingCute.magic_2_line),
  Icons.tab_outlined: ThemeSymbol(ThemeNavIcon.tabs.iconKey, mingcute: MingCute.dashboard_line),
  Icons.dns_outlined: ThemeSymbol(ThemeNavIcon.server.iconKey, mingcute: MingCute.server_line),
  Icons.sort: ThemeSymbol(ThemeNavIcon.sort.iconKey, mingcute: MingCute.sort_ascending_line),
  Icons.terminal: ThemeSymbol(ThemeNavIcon.terminal.iconKey, mingcute: MingCute.terminal_line),
  Icons.folder_outlined: ThemeSymbol(ThemeNavIcon.folder.iconKey, mingcute: MingCute.folder_line),
  Icons.cloud_outlined: ThemeSymbol(ThemeNavIcon.cloud.iconKey, mingcute: MingCute.cloud_line),
  Icons.edit_note: ThemeSymbol(ThemeNavIcon.snippet.iconKey, mingcute: MingCute.code_line),
  Icons.inbox_outlined: ThemeSymbol(ThemeNavIcon.inbox.iconKey, mingcute: MingCute.inbox_line),
  Icons.key_outlined: ThemeSymbol(ThemeNavIcon.key.iconKey, mingcute: MingCute.key_2_line),
  Icons.info_outline: ThemeSymbol(ThemeNavIcon.info.iconKey, mingcute: MingCute.information_line),
  Icons.file_download_outlined: ThemeSymbol(ThemeNavIcon.download.iconKey, mingcute: MingCute.download_line),
  Icons.desktop_windows_outlined: ThemeSymbol(ThemeNavIcon.desktop.iconKey, mingcute: MingCute.computer_line),
};

List<Widget> _previewBody(BuildContext context, ThemePreviewIcon icon) => [
  _server(context, icon, 'web-01', 0.42, 0.68),
  _server(context, icon, 'db-primary', 0.18, 0.81),
  ListTile(
    selected: true,
    leading: icon('nav.terminal', Icons.terminal),
    title: const Text('ssh web-01'),
    onTap: () {},
  ),
];

Widget _server(
  BuildContext context,
  ThemePreviewIcon icon,
  String name,
  double cpu,
  double mem,
) {
  final scheme = Theme.of(context).colorScheme;
  return Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 7,
        children: [
          Row(
            children: [
              icon('nav.server', Icons.dns_outlined),
              UIs.width7,
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: scheme.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          LinearProgressIndicator(value: cpu),
          LinearProgressIndicator(value: mem, color: scheme.secondary),
        ],
      ),
    ),
  );
}
