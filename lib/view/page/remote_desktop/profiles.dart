// The list and the actions on it are laid out by extensions rather than in the
// state class's own body — see the project's rule on splitting a page into
// widgets, actions and utils — and selecting a row has to call `setState` from
// one of them.
// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/view/page/remote_desktop/pane_slide.dart';
import 'package:server_box/view/page/remote_desktop/profile_edit.dart';
import 'package:server_box/view/widget/pane_settings.dart';

/// One server's remote desktop profiles: a list, and the form each row opens.
///
/// Two columns where there is room for two, the same way the snippet, server
/// and benchmark pages are laid out — a record list on the left and what is
/// done with one on the right. This page was the app's only list-and-form pair
/// that did not: the list filled the window and the form arrived as a modal
/// over the list that opened it.
///
/// A profile can be connected or edited directly from its list row.
/// Inside the remote desktop tab, the enclosing server rail owns the other
/// column, so this page shows the list and form in that column in turn.
final class RemoteDesktopProfilesPage extends ConsumerStatefulWidget {
  const RemoteDesktopProfilesPage({
    super.key,
    required this.args,
    this.onBack,
    this.onSessionOpened,
    this.onTestSessionOpening,
  });

  final SpiRequiredArgs args;

  /// When embedded in the remote desktop tab, keep the form in its pane.
  final VoidCallback? onBack;
  final VoidCallback? onSessionOpened;
  final ValueChanged<String?>? onTestSessionOpening;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: RemoteDesktopProfilesPage.new,
    path: '/remote_desktop_profiles',
  );

  @override
  ConsumerState<RemoteDesktopProfilesPage> createState() =>
      _RemoteDesktopProfilesPageState();
}

/// What the pane is on when it is on a profile being added.
const _newProfile = #newRemoteDesktopProfile;

class _RemoteDesktopProfilesPageState
    extends ConsumerState<RemoteDesktopProfilesPage> {
  /// The id of the profile being edited, [_newProfile] for one being added, or
  /// null for nothing.
  ///
  /// The id rather than the object: the object is replaced on every save, and
  /// the id is what a session opened from that form is keyed by.
  Object? _editing;

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(
      remoteDesktopProfilesProvider(widget.args.spi.id),
    );
    final editing = switch (_editing) {
      final String id => profiles.firstWhereOrNull((e) => e.id == id),
      _ => null,
    };
    // A profile deleted from under the pane. Cleared next frame rather than
    // now, because this runs during a build.
    final gone = _editing is String && editing == null;
    if (gone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editing is String) setState(() => _editing = null);
      });
    }

    if (widget.onBack != null) {
      final pane = _editing == null || gone
          ? _buildList(profiles, false)
          : RemoteDesktopProfileEditPage(
              args: RemoteDesktopProfileEditArgs(
                serverId: widget.args.spi.id,
                profile: editing,
                onClose: () => setState(() => _editing = null),
                onTestSessionOpening: widget.onTestSessionOpening,
              ),
            );
      return NestedNavigator(
        rootId: gone ? null : _editing,
        rootBuilder: (_) => pane,
      );
    }

    return RemoteDesktopPaneSlide(
      child: PaneSettings.listenAll((paneWidth, paneCollapsed) {
        return AdaptivePanes.detail(
          listWidth: paneWidth,
          onListWidthChanged: PaneSettings.saveWidth,
          collapsed: paneCollapsed,
          onCollapsedChanged: PaneSettings.saveCollapsed,
          collapseTooltip: libL10n.fold,
          expandTooltip: libL10n.open,
          detailId: _editing,
          onCloseDetail: () => setState(() => _editing = null),
          // Never null, so the two columns are what this page looks like from the
          // moment it opens. A null builder hands the whole width back to the
          // list, which made the first thing anyone saw a full-width list that
          // rearranged itself into a column as soon as a row was tapped.
          //
          // `_editing` is the sentinel for a new profile, so the pane shows a
          // form for it exactly as it does for a saved one — and shows nothing at
          // all for an id whose record has just gone.
          detailBuilder: (_) => _editing == null || gone
              ? const EmptyPane(icon: Icons.desktop_windows_outlined)
              : RemoteDesktopProfileEditPage(
                  args: RemoteDesktopProfileEditArgs(
                    serverId: widget.args.spi.id,
                    profile: editing,
                  ),
                ),
          listBuilder: (_, split) => _buildList(profiles, split),
        );
      }),
    );
  }
}

// --- Widgets ---

extension _Widgets on _RemoteDesktopProfilesPageState {
  Widget _buildList(List<RemoteDesktopProfile> profiles, bool split) {
    return Scaffold(
      appBar: CustomAppBar(
        // A route's list is already the back destination for its detail.
        // Embedded in the tab, Back returns to the session or server picker.
        leading: widget.onBack == null
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
        title: TwoLineText(
          up: l10n.remoteDesktop,
          down: widget.args.spi.name,
          mark: const BetaTag(),
        ),
        actions: [
          Btn.icon(
            text: libL10n.add,
            icon: const Icon(Icons.add, size: 18),
            onTap: () => _edit(null, split),
          ),
        ],
      ),
      body: profiles.isEmpty
          ? _empty(split)
          : split
          ? _buildRail(profiles)
          : _buildCards(profiles),
    );
  }

  /// The narrow column: a name and nothing else, like every other rail here.
  Widget _buildRail(List<RemoteDesktopProfile> profiles) {
    return ListView(
      // Room at the bottom for the add button to float over, the way the
      // server rail leaves it.
      padding: const EdgeInsets.only(top: 4, bottom: 77),
      children: [
        for (final profile in profiles)
          SideBarTile(
            key: ValueKey(profile.id),
            title: profile.name,
            icon: profile.protocol == RemoteDesktopProtocol.rdp
                ? Icons.desktop_windows_outlined
                : Icons.connected_tv_outlined,
            selected: _editing == profile.id,
            live: _isOpen(profile),
            onTap: () => _edit(profile, true),
            onMenu: (at) => _showRowMenu(profile, at),
          ),
      ],
    );
  }

  /// The whole width: what each profile is and where it points.
  Widget _buildCards(List<RemoteDesktopProfile> profiles) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 77),
          itemCount: profiles.length,
          itemBuilder: (_, index) {
            final profile = profiles[index];
            return LayoutBuilder(
              builder: (_, constraints) {
                final compact = constraints.maxWidth < 480;
                return CardTile(
                  key: ValueKey(profile.id),
                  icon: profile.protocol == RemoteDesktopProtocol.rdp
                      ? Icons.desktop_windows_outlined
                      : Icons.connected_tv_outlined,
                  title: profile.name,
                  subtitle:
                      '${profile.protocol.name.toUpperCase()} · '
                      '${profile.host}:${profile.port}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isOpen(profile)) ...[
                        const _LiveMark(),
                        const SizedBox(width: 8),
                      ],
                      if (compact)
                        IconButton(
                          tooltip: l10n.connect,
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => _connect(profile),
                        )
                      else
                        TextButton.icon(
                          onPressed: () => _connect(profile),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(l10n.connect),
                        ),
                      if (compact)
                        IconButton(
                          tooltip: libL10n.edit,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(profile, false),
                        )
                      else
                        TextButton.icon(
                          onPressed: () => _edit(profile, false),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(libL10n.edit),
                        ),
                    ],
                  ),
                  onTap: () => _connect(profile),
                  onLongPress: () => _showRowMenu(profile, null),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _empty(bool split) {
    final add = FilledButton.icon(
      onPressed: () => _edit(null, split),
      icon: const Icon(Icons.add),
      label: Text(l10n.remoteDesktopAddProfile),
    );
    // In the rail's place the button is in the bar already, so the empty pane
    // only has to say what is missing.
    return EmptyPane(
      icon: Icons.desktop_windows_outlined,
      label: l10n.remoteDesktopNoProfiles,
      action: split ? null : add,
    );
  }

  bool _isOpen(RemoteDesktopProfile profile) => ref.watch(
    remoteDesktopSessionsProvider.select(
      (state) => state.sessions.containsKey(profile.id),
    ),
  );
}

/// Says a session is already open on the row it marks.
final class _LiveMark extends StatelessWidget {
  const _LiveMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: libL10n.ready,
      excludeSemantics: true,
      child: Tooltip(
        message: libL10n.ready,
        excludeFromSemantics: true,
        child: const Icon(Icons.circle, size: 9, color: Colors.green),
      ),
    );
  }
}

// --- Actions ---

extension _Actions on _RemoteDesktopProfilesPageState {
  Future<void> _connect(RemoteDesktopProfile profile) async {
    if (await openRemoteDesktop(context, ref, profile) && mounted) {
      widget.onSessionOpened?.call();
    }
  }

  /// Opens [profile] — or a new one when null — in the editor beside the list,
  /// or over it when there is no room for a second column.
  void _edit(RemoteDesktopProfile? profile, bool split) {
    if (split || widget.onBack != null) {
      setState(() => _editing = profile?.id ?? _newProfile);
      return;
    }
    RemoteDesktopProfileEditPage.route.go(
      context,
      RemoteDesktopProfileEditArgs(
        serverId: widget.args.spi.id,
        profile: profile,
      ),
    );
  }

  void _showRowMenu(RemoteDesktopProfile profile, Offset? at) {
    showContextMenu(
      context,
      [
        ContextMenuAction(
          text: l10n.connect,
          icon: Icons.play_arrow,
          onTap: () => _connect(profile),
        ),
        ContextMenuAction(
          text: libL10n.edit,
          icon: Icons.edit_outlined,
          // Selected rather than pushed: this is the row the pane is about to
          // show, and a menu is not a second way to leave the layout.
          onTap: () => setState(() => _editing = profile.id),
        ),
        ContextMenuAction(
          text: libL10n.delete,
          icon: Icons.delete_outline,
          destructive: true,
          onTap: () => _delete(profile),
        ),
      ],
      title: profile.name,
      at: at,
    );
  }

  Future<void> _delete(RemoteDesktopProfile profile) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.remoteDesktopDeleteProfile(profile.name)),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(remoteDesktopSessionsProvider.notifier)
        .closeForProfile(profile.id);
    ref
        .read(remoteDesktopProfilesProvider(widget.args.spi.id).notifier)
        .remove(profile);
  }
}
