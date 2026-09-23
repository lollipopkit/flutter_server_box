import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/view/page/remote_desktop/profile_edit.dart';

/// One server's remote desktop profiles.
///
/// The list is an index and the editor is what it opens: a profile is a record
/// to be set up, corrected and deleted, and every other list in this app reads
/// that way. Tapping a row used to connect straight away, which made this list
/// the only one in the app where a tap was not "what is this" — and left the
/// form behind a modal dialog that had nowhere to put a Save bar.
///
/// Connecting is still one tap from here: the row menu offers it, so a profile
/// that is already set up is used without opening it first.
final class RemoteDesktopProfilesPage extends ConsumerStatefulWidget {
  const RemoteDesktopProfilesPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: RemoteDesktopProfilesPage.new,
    path: '/remote_desktop_profiles',
  );

  @override
  ConsumerState<RemoteDesktopProfilesPage> createState() =>
      _RemoteDesktopProfilesPageState();
}

class _RemoteDesktopProfilesPageState
    extends ConsumerState<RemoteDesktopProfilesPage> {
  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(remoteDesktopProfilesProvider(widget.args.spi.id));
    return Scaffold(
      appBar: CustomAppBar(
        // No back button of its own: as a pane's list column this bar has
        // nowhere to go, and `CustomAppBar` would otherwise offer the pane's
        // close-detail button here — the list is not what closes.
        leading: const SizedBox.shrink(),
        title: TwoLineText(up: 'Remote desktop', down: widget.args.spi.name),
        actions: [
          IconButton(
            tooltip: libL10n.add,
            icon: const Icon(Icons.add),
            onPressed: () => _edit(),
          ),
        ],
      ),
      body: profiles.isEmpty ? _empty() : _buildList(profiles),
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.desktop_windows_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text('No remote desktop profiles', style: UIs.textGrey),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Add profile'),
        ),
      ],
    ),
  );
}

// --- Widgets ---

extension _Widgets on _RemoteDesktopProfilesPageState {
  Widget _buildList(List<RemoteDesktopProfile> profiles) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 77),
      itemCount: profiles.length,
      itemBuilder: (_, index) => _buildTile(profiles[index]),
    );
  }

  Widget _buildTile(RemoteDesktopProfile profile) {
    final open = ref.watch(
      remoteDesktopSessionsProvider.select(
        (state) => state.sessions.containsKey(profile.id),
      ),
    );
    return CardTile(
      key: ValueKey(profile.id),
      icon: profile.protocol == RemoteDesktopProtocol.rdp
          ? Icons.desktop_windows_outlined
          : Icons.connected_tv_outlined,
      title: profile.name,
      subtitle:
          '${profile.protocol.name.toUpperCase()} · ${profile.host}:${profile.port}',
      // The chevron `CardTile` defaults to, or the mark that says a session is
      // already open on this profile. Passing null would say the row opens
      // nothing, which is the opposite of what a tap here does.
      trailing: open
          ? Semantics(
              label: libL10n.ready,
              excludeSemantics: true,
              child: Tooltip(
                message: libL10n.ready,
                excludeFromSemantics: true,
                child: const Icon(Icons.circle, size: 9, color: Colors.green),
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => _edit(profile),
      onLongPress: () => _showRowMenu(profile),
    );
  }
}

// --- Actions ---

extension _Actions on _RemoteDesktopProfilesPageState {
  /// Opens [profile] — or a new one when null — in the editor.
  void _edit([RemoteDesktopProfile? profile]) {
    RemoteDesktopProfileEditPage.route.go(
      context,
      RemoteDesktopProfileEditArgs(
        serverId: widget.args.spi.id,
        profile: profile,
      ),
    );
  }

  void _showRowMenu(RemoteDesktopProfile profile) {
    showContextMenu(
      context,
      [
        ContextMenuAction(
          text: 'Connect',
          icon: Icons.play_arrow,
          onTap: () => openRemoteDesktop(context, ref, profile),
        ),
        ContextMenuAction(
          text: libL10n.edit,
          icon: Icons.edit_outlined,
          onTap: () => _edit(profile),
        ),
        ContextMenuAction(
          text: libL10n.delete,
          icon: Icons.delete_outline,
          destructive: true,
          onTap: () => _delete(profile),
        ),
      ],
      title: profile.name,
    );
  }

  Future<void> _delete(RemoteDesktopProfile profile) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text('Delete remote desktop profile “${profile.name}”?'),
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
