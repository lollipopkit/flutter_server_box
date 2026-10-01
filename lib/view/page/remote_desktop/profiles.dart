// The list and the actions on it are laid out by extensions rather than in the
// state class's own body — see the project's rule on splitting a page into
// widgets, actions and utils — and selecting a row has to call `setState` from
// one of them.
// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/view/page/remote_desktop/profile_edit.dart';

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
    required this.onBack,
    this.onSessionOpened,
    this.onTestSessionOpening,
  });

  final SpiRequiredArgs args;

  /// Back to the session or server picker of the remote desktop tab, which
  /// this page is always part of: a server's profiles are reached by selecting
  /// the server there (`RemoteDesktopServerRequest`), not as a page of their
  /// own.
  final VoidCallback onBack;
  final VoidCallback? onSessionOpened;
  final ValueChanged<String?>? onTestSessionOpening;

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

    final pane = _editing == null || gone
        ? _buildList(profiles)
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
}

// --- Widgets ---

extension _Widgets on _RemoteDesktopProfilesPageState {
  Widget _buildList(List<RemoteDesktopProfile> profiles) {
    return Scaffold(
      appBar: CustomAppBar(
        // Back returns to the tab's session or server picker.
        leading: IconButton(
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
            onTap: () => _edit(null),
          ),
        ],
      ),
      body: profiles.isEmpty ? _empty() : _buildCards(profiles),
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
                          onPressed: () => _edit(profile),
                        )
                      else
                        TextButton.icon(
                          onPressed: () => _edit(profile),
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

  Widget _empty() => EmptyPane(
    icon: Icons.desktop_windows_outlined,
    label: l10n.remoteDesktopNoProfiles,
    action: FilledButton.icon(
      onPressed: () => _edit(null),
      icon: const Icon(Icons.add),
      label: Text(l10n.remoteDesktopAddProfile),
    ),
  );

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

  /// Opens [profile] — or a new one when null — in the editor, in this pane.
  void _edit(RemoteDesktopProfile? profile) =>
      setState(() => _editing = profile?.id ?? _newProfile);

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
