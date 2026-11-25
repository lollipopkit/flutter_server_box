import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/crash_report.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/view/page/setting/entries/ai.dart';
import 'package:server_box/view/page/setting/entries/app.dart';
import 'package:server_box/view/page/setting/entries/container.dart';
import 'package:server_box/view/page/setting/entries/editor.dart';
import 'package:server_box/view/page/setting/entries/full_screen.dart';
import 'package:server_box/view/page/setting/entries/linux.dart';
import 'package:server_box/view/page/setting/entries/mcp.dart';
import 'package:server_box/view/page/setting/entries/remote_desktop.dart';
import 'package:server_box/view/page/setting/entries/server.dart';
import 'package:server_box/view/page/setting/entries/sftp.dart';
import 'package:server_box/view/page/setting/entries/ssh.dart';
import 'package:server_box/view/page/setting/group.dart';
import 'package:server_box/view/page/setting/helpers.dart';
import 'package:server_box/view/page/setting/menu.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';
import 'package:server_box/view/widget/group_title.dart';
import 'package:server_box/view/widget/marked_title.dart';

/// Which group of settings [AppSettingsPage] is showing.
///
/// One page rather than one per group, so that the state — and the four text
/// controllers on it — survives moving between them.
enum SettingsSection {
  app,
  /// What the app looks like: the theme in all of its parts, and the font.
  appearance,
  privacy,
  ai,
  mcp,
  server,
  ssh,
  linux,
  sftp,
  container,
  /// The remote desktop tab's sessions and a guest's consoles: what they
  /// have in common, which is how long one stays open once it is left.
  remoteDesktop,
  editor,
  fullScreen;

  /// What this group is called when it is a page of its own.
  ///
  /// The *subject's* name rather than the leaf's. Inside the settings the menu
  /// beside a group already says which subject you are in, so three of those
  /// leaves are called "General" — which on a page with nothing beside it names
  /// nothing at all.
  String get title => switch (this) {
    SettingsSection.app => libL10n.app,
    SettingsSection.appearance => libL10n.appearanceSettings,
    SettingsSection.privacy => l10n.privacy,
    SettingsSection.ai => libL10n.ai,
    SettingsSection.mcp => l10n.appMcpServer,
    SettingsSection.server => libL10n.server,
    SettingsSection.ssh => libL10n.terminal,
    // Not localized: the id is what the settings search matches on, and Linux
    // is the same word in every locale this ships in.
    SettingsSection.linux => 'Linux',
    SettingsSection.sftp => 'SFTP',
    SettingsSection.container => libL10n.container,
    SettingsSection.remoteDesktop => l10n.remoteDesktop,
    SettingsSection.editor => libL10n.editor,
    SettingsSection.fullScreen => l10n.fullScreen,
  };

  /// The feature this section is, whose mark [title] carries where it is
  /// shown.
  Feature? get feature => this == SettingsSection.linux ? Feature.linux : null;

  /// The page this group is, inside the subject it is under.
  ///
  /// What the search puts over a row it found: three of these pages are called
  /// "General", and the subject is the half that tells them apart.
  String get breadcrumb => switch (this) {
    SettingsSection.app => '${libL10n.app} › ${libL10n.general}',
    SettingsSection.appearance => '${libL10n.app} › ${libL10n.appearanceSettings}',
    SettingsSection.privacy => '${libL10n.app} › ${l10n.privacy}',
    SettingsSection.ai => libL10n.ai,
    SettingsSection.mcp => '${libL10n.ai} › ${SettingsSection.mcp.title}',
    SettingsSection.fullScreen => '${libL10n.app} › ${l10n.fullScreen}',
    SettingsSection.server => '${libL10n.server} › ${libL10n.general}',
    SettingsSection.ssh => '${libL10n.terminal} › ${libL10n.general}',
    SettingsSection.linux => '${libL10n.terminal} › Linux',
    SettingsSection.sftp => '${libL10n.file} › SFTP',
    SettingsSection.editor => '${libL10n.file} › ${libL10n.editor}',
    SettingsSection.container => libL10n.container,
    SettingsSection.remoteDesktop => '${libL10n.server} › ${l10n.remoteDesktop}',
  };

  /// Whether this build has this group at all.
  ///
  /// The search walks every one of them, and a group the menu never offers is
  /// one whose rows cannot be reached from a result either.
  bool get available => switch (this) {
    SettingsSection.linux => Rootfs.isAvailable,
    _ => true,
  };
}

/// One settings group as a page of its own.
///
/// For the places outside the settings tree that lead into it — the terminal
/// tab's "add a Linux system" is the one there is.
///
/// A wrapper rather than an `embedded` flag on [AppSettingsPage], which is what
/// the three sibling pages in the menu use: that page is a group's rows and
/// nothing else, on nine call sites, because the settings' own layout supplies
/// the bar, the title and the surface. Pushed as a route it was a `ListView` on
/// an empty one — a black screen with settings on it.
final class SettingsSectionPage extends StatelessWidget {
  const SettingsSectionPage({super.key, required this.args});

  final SettingsSection args;

  /// A route rather than a `Navigator.push` written at the call site, and the
  /// difference is not bookkeeping: `AppRoute` decides *which* navigator the
  /// page lands on and puts the desktop window frame round it when that is the
  /// root one. On the nearest navigator — what a bare push finds — a page
  /// opened from a tab lands inside that tab, so the settings replaced the
  /// terminal's contents with the navigation still under them, and from the
  /// side bar beside the terminals they opened in that narrow column. A caller
  /// that means the whole window says [NavTarget.root].
  static const route = AppRouteArg<void, SettingsSection>(
    page: SettingsSectionPage.new,
    path: '/settings/section',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: MarkedTitle(
          args.title,
          // What a beta page warns about, on the mark rather than in a row
          // of its own above the settings.
          mark: args.feature?.mark(tip: l10n.betaTip),
        ),
      ),
      body: AppSettingsPage(section: args),
    );
  }
}

/// What the page shows instead of its own group while a search is on.
///
/// The search is rendered here and not beside the menu, because what it looks
/// through is the rows this page builds — and those are built from a state
/// with five text controllers on it, which nothing outside can construct.
final class SettingsSearch {
  const SettingsSearch({
    required this.query,
    required this.pages,
    required this.onPage,
  });

  final String query;

  /// Pages whose own names match, found by the menu rather than here.
  final List<SettingsHit> pages;

  final void Function(SettingsHit hit) onPage;
}

final class AppSettingsPage extends ConsumerStatefulWidget {
  final SettingsSection section;

  /// When set, every section's matching rows instead of this one's own.
  final SettingsSearch? search;

  const AppSettingsPage({super.key, required this.section, this.search});

  /// No route of its own — see [SettingsSectionPage], which is what a caller
  /// outside the settings tree pushes. This builds a group's rows and nothing
  /// else: no bar, no background, no scaffold.

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

final class _AppSettingsPageState extends AppSettingsHost<AppSettingsPage> {

  /// The kept crash report, read once in [initState]. Null again after it is
  /// dropped, which is what makes its group disappear.
  String? _savedCrashReport;

  @override
  String? get savedCrashReport => _savedCrashReport;

  @override
  void clearSavedCrashReport() {
    _savedCrashReport = null;
    refresh();
  }

  /// Whether this device can ask for a fingerprint or a face. Null until the
  /// platform has answered, which is not a row and not a group.
  bool? _bioAuthAvail;

  @override
  bool? get bioAuthAvail => _bioAuthAvail;

  @override
  late final sshOpacityCtrl = TextEditingController(
    text: setting.sshBgOpacity.fetch().toString(),
  );
  @override
  late final sshBlurCtrl = TextEditingController(
    text: setting.sshBlurRadius.fetch().toString(),
  );
  @override
  late final textScalerCtrl = TextEditingController(
    // `.fetch()`, as the three above: without it the field opened showing
    // `Instance of 'SqlitePropDefault<double>'` and handed that to be parsed.
    text: setting.textFactor.fetch().toString(),
  );
  @override
  late final serverLogoCtrl = TextEditingController(
    text: setting.serverLogoUrl.fetch(),
  );
  @override
  late final serverMarkCtrl = TextEditingController(
    text: setting.serverMarkUrl.fetch(),
  );

  @override
  void openMcpSettings() =>
      SettingsSectionPage.route.go(context, SettingsSection.mcp);

  @override
  void initState() {
    super.initState();
    // Which releases are installable is fetched rather than compiled in, and
    // this page is where someone is about to act on the answer: the version
    // beside "add", the update button on a profile. Launch already tries once;
    // this catches the case where it failed or the release moved since.
    //
    // Not awaited and not shown. What is in force already works, and a refresh
    // that changes nothing — the ordinary case — should look like nothing.
    if (widget.section == SettingsSection.linux && Rootfs.isAvailable) {
      RootfsManifestSource.refresh().then((changed) {
        if (changed && mounted) setState(() {});
      });
    }

    // Both of these decide whether a whole group exists, so they are answered
    // once here rather than by a builder inside a row: a row that arrived a
    // frame later left a heading and a hairline with nothing under them.
    unawaited(
      CrashReport.saved().then((report) {
        if (!mounted || report == null) return;
        setState(() => _savedCrashReport = report);
      }),
    );
    unawaited(
      PlatformPublicSettings.bioAuthAvailable.then((avail) {
        if (!mounted || !avail) return;
        setState(() => _bioAuthAvail = true);
      }),
    );
  }

  @override
  void dispose() {
    sshOpacityCtrl.dispose();
    sshBlurCtrl.dispose();
    textScalerCtrl.dispose();
    serverLogoCtrl.dispose();
    serverMarkCtrl.dispose();
    super.dispose();
  }

  /// What a group of settings is made of, named and in order.
  ///
  /// A function of the section rather than a field, because the search walks
  /// every one of them — see [_buildSearch].
  List<SettingsGroup> _groupsOf(SettingsSection section) => switch (section) {
    SettingsSection.app => buildAppSettings(),
    SettingsSection.appearance => buildAppearanceSettings(),
    SettingsSection.privacy => buildPrivacySettings(),
    SettingsSection.ai => buildAskAiConfig(),
    SettingsSection.mcp => buildMcpSettings(),
    SettingsSection.server => buildServerSettings(),
    SettingsSection.ssh => buildSshSettings(),
    SettingsSection.linux => buildLinuxSettings(),
    SettingsSection.sftp => buildSftpSettings(),
    SettingsSection.container => buildContainerSettings(),
    SettingsSection.remoteDesktop => buildRemoteDesktopSettings(),
    SettingsSection.editor => buildEditorSettings(),
    SettingsSection.fullScreen => buildFullScreenSettings(),
  };

  /// Every row of every group there is, that [query] names.
  ///
  /// The rows themselves, drawn as they are drawn on their own page — so a
  /// switch found by searching is a switch, and flipping it here is flipping
  /// it. Each section's matches carry its own heading, which is where the row
  /// lives; a breadcrumb repeated on every row would say it once per line.
  List<SettingsGroup> _matchingGroups(String query) {
    final needle = query.toLowerCase();
    final groups = <SettingsGroup>[];
    for (final section in SettingsSection.values) {
      if (!section.available) continue;
      final rows = [
        for (final group in _groupsOf(section))
          ...group.rows.where((row) => row.matches(needle)),
      ];
      if (rows.isNotEmpty) groups.add(SettingsGroup(section.breadcrumb, rows));
    }
    return groups;
  }

  Widget _buildSearch(SettingsSearch search) {
    final groups = _matchingGroups(search.query);
    final pages = search.pages;
    final total = groups.fold<int>(pages.length, (n, g) => n + g.rows.length);

    // The pages themselves, under the settings on them: somebody typing
    // "sequence" means the page, and somebody typing "font" means a row.
    final pageGroup = pages.isEmpty
        ? null
        : SettingsGroup(libL10n.setting, [
            for (final hit in pages)
              SettingsRow(
                hit.leaf.title,
                () => ListTile(
                  leading: ThemedIcon(hit.leaf.icon),
                  title: hit.leaf.titleWidget(),
                  subtitle: hit.parent == null
                      ? null
                      : Text(hit.parent!.title, style: UIs.text11Grey),
                  trailing: const Icon(Icons.keyboard_arrow_right),
                  onTap: () => search.onPage(hit),
                ),
              ),
          ]);

    return Column(
      key: settingsResultsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GroupTitle(
          '$total ${libL10n.result}',
          padding: const EdgeInsets.fromLTRB(3, 0, 3, 7),
        ),
        // A keystroke rewrites this whole list, and which of it changed is
        // the one thing that cannot be read off the result. So a section that
        // stops matching shrinks away and one that starts matching grows in,
        // and the rest of the column flows around it.
        AnimatedColumn(
          duration: context.motion(Durations.medium2),
          children: [
            for (final group in [...groups, ?pageGroup])
              Padding(
                key: ValueKey('group:${group.title}'),
                padding: const EdgeInsets.only(bottom: 13),
                child: SettingsGroupView(group, animated: true),
              ),
            // An entry like any other, so that it grows in as the last group
            // shrinks out. Returned early instead, it replaced the column —
            // state and all — and the groups it was replacing had nothing
            // left to leave from.
            if (total == 0)
              Padding(
                key: const ValueKey('empty'),
                padding: const EdgeInsets.symmetric(vertical: 34),
                child: Center(child: Text(libL10n.empty, style: UIs.textGrey)),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.search case final search?) return _buildSearch(search);

    // The grid rather than one tall column. A settings row is a label at one
    // end and a control at the other, and on a desktop window a single column
    // of them put the two a hand's width apart and made the page a screen and
    // a half of scrolling. [PageColumns] is what the rest of the app's forms
    // are laid out in, at a width chosen for exactly this kind of row.
    //
    // No heading over the grid itself: the menu says which group this is, and
    // the header above the content repeats it. The headings inside are the
    // groups' own.
    Widget grid() => PageColumns(
      padding: kSettingsGridPadding,
      spacing: kSettingsGridSpacing,
      bottomInset: MediaQuery.paddingOf(context).bottom,
      children: [
        // A group can come out empty — every row in it is behind a platform
        // test — and an empty one is a heading with a rule and nothing under.
        for (final group in _groupsOf(widget.section))
          if (group.rows.isNotEmpty) SettingsGroupView(group),
      ],
    );

    // See [LinuxSettingEntries.buildLinuxSettings]: its rows are about
    // whichever profile is selected, and nothing else here notifies when that
    // changes.
    if (widget.section != SettingsSection.linux) return grid();
    return ValBuilder(
      listenable: setting.linuxProfile.listenable(),
      builder: (_) => grid(),
    );
  }

}
