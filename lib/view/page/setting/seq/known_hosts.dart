import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/res/store.dart';

/// Every host key this app has accepted, and a way to take one back.
///
/// The app files a fingerprint the first time a server offers one and checks
/// it on every connection after that — which is what makes a changed key a
/// question rather than a silent reconnect. Until this page there was no way
/// to undo that: `forgetHostKeyFingerprints` existed, had tests, and was
/// reachable only from the cleanup that runs when an ad-hoc connection is
/// dropped.
///
/// So a server that was rebuilt, or a key that was rotated, left the app
/// refusing with no way forward, and a key accepted by mistake stayed accepted.
class KnownHostsPage extends StatefulWidget {
    /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const KnownHostsPage({super.key, this.embedded = false});

  @override
  State<KnownHostsPage> createState() => _KnownHostsPageState();

  static const route = AppRouteNoArg(
    page: KnownHostsPage.new,
    path: '/settings/known_hosts',
  );
}

class _KnownHostsPageState extends State<KnownHostsPage> {
  late Map<String, List<KnownHostKey>> _grouped;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _grouped = groupHostKeysByServer(
      Stores.setting.sshKnownHostFingerprints.get(),
    );
  }

  /// The server's name, or its bare id where there is no server any more.
  ///
  /// An id with nothing behind it is the normal end of an ad-hoc connection
  /// and of a server since deleted. Shown rather than hidden: it is something
  /// this app still trusts, and the whole point of the page is to be able to
  /// see that.
  String _label(String serverId) {
    for (final spi in Stores.server.fetch()) {
      if (spi.id == serverId) return spi.name;
    }
    return '${libL10n.unknown} ($serverId)';
  }

  Future<void> _forget({String? storageKey, String? serverId}) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue(
          '${libL10n.delete} ${storageKey == null ? _label(serverId!) : ''}'
              .trim(),
        ),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    if (storageKey != null) {
      forgetHostKey(storageKey);
    } else {
      forgetHostKeyFingerprints(serverId!);
    }
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final body = _grouped.isEmpty
        ? Center(child: Text(libL10n.empty, style: UIs.textGrey))
        : ListView(
            padding: context.padBottom(const EdgeInsets.all(7)),
            children: [
              CardX(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Text(l10n.sshKnownHostKeysTip, style: UIs.textGrey),
                ),
              ),
              for (final entry in _grouped.entries)
                CardX(child: _buildServer(entry.key, entry.value)),
            ],
          );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.sshKnownHostKeys)),
      body: body,
    );
  }

  Widget _buildServer(String serverId, List<KnownHostKey> keys) {
    return ExpandTile(
      leading: const Icon(Icons.dns),
      title: Text(_label(serverId)),
      subtitle: Text(
        '${keys.length} ${l10n.sshHostKeyType}',
        style: UIs.text13Grey,
      ),
      trailing: IconButton(
        tooltip: libL10n.delete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _forget(serverId: serverId),
      ),
      children: [
        for (final key in keys)
          ListTile(
            title: Text(
              key.keyType.isEmpty ? libL10n.unknown : key.keyType,
              style: UIs.text13,
            ),
            // The fingerprint in full, wrapped rather than cut: what it is for
            // is being compared against what the server says, and half of one
            // compares equal to nothing.
            subtitle: Text(key.fingerprint, style: UIs.text11Grey),
            trailing: IconButton(
              tooltip: libL10n.delete,
              icon: const Icon(Icons.close, size: 17),
              onPressed: () => _forget(storageKey: key.storageKey),
            ),
          ),
      ],
    );
  }
}
