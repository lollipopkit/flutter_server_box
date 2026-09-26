part of 'tab.dart';

/// The host switcher: the hosts, then every other server under "Check this
/// server", so a server is never missing only because nobody asked it yet.
///
/// One widget for the list column and the sheet, watching the providers
/// itself so a probe finishing while it is open moves its row up.
class _VirtHostPicker extends ConsumerWidget {
  const _VirtHostPicker({
    super.key,
    required this.selectedId,
    required this.onSelect,
    required this.onCheck,
    required this.onSetUpPve,
  });

  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Probes a server; true when it turned out to be a host.
  final Future<bool> Function(String serverId) onCheck;

  /// Offers PVE's API access for a server found running it; true when it
  /// became a host.
  final Future<bool> Function(String serverId) onSetUpPve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(virtHostsProvider);
    final servers = ref.watch(serversProvider).servers;
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 17),
      children: [
        SideBarSection(l10n.virtHosts),
        if (hosts.hosts.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 3, 17, 9),
            child: Text(l10n.virtNoHosts, style: UIs.text13Grey),
          ),
        for (final MapEntry(key: id, value: kind) in hosts.hosts.entries)
          if (servers[id] case final spi?)
            SideBarTile(
              key: ValueKey('host:$id'),
              title: spi.name,
              icon: Icons.dns_outlined,
              selected: id == selectedId,
              trailing: Text(kind.label, style: UIs.text12Grey),
              onTap: () => onSelect(id),
            ),
        if (hosts.others.isNotEmpty) ...[
          UIs.height13,
          SideBarSection(l10n.virtCheckServer),
          for (final id in hosts.others)
            if (servers[id] case final spi?)
              SideBarTile(
                key: ValueKey('other:$id'),
                title: spi.name,
                trailing: _ProbeStatus(hosts.probes[id]),
                onTap: switch (hosts.probes[id]?.status) {
                  VirtProbeStatus.probing => null,
                  VirtProbeStatus.pve => () => unawaited(onSetUpPve(id)),
                  _ => () => unawaited(onCheck(id)),
                },
              ),
        ],
      ],
    );
  }
}

/// What probing a server found, at the end of its row.
class _ProbeStatus extends StatelessWidget {
  const _ProbeStatus(this.probe);

  final VirtProbe? probe;

  /// Held to part of the row, so a long translation cuts itself short rather
  /// than the server's name; the whole of it is a hover away.
  static Widget _note(String text) => Tooltip(
    message: text,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: UIs.text12Grey,
      ),
    ),
  );

  /// `systemd-detect-virt`'s names, as their projects write them.
  static String _containerName(String kind) => switch (kind) {
    'lxc' || 'lxc-libvirt' => 'LXC',
    'docker' => 'Docker',
    'podman' => 'Podman',
    'systemd-nspawn' => 'nspawn',
    'openvz' => 'OpenVZ',
    'wsl' => 'WSL',
    _ => kind,
  };

  @override
  Widget build(BuildContext context) {
    final probe = this.probe;
    return switch (probe?.status) {
      null => _note(l10n.virtProbeNotChecked),
      VirtProbeStatus.probing => const SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      VirtProbeStatus.pve => _note(l10n.virtProbePve),
      VirtProbeStatus.absent => switch (probe!.container) {
        final kind? => Tooltip(
          message: l10n.virtProbeContainerTip,
          child: _note(l10n.virtProbeContainer(_containerName(kind))),
        ),
        null => _note(l10n.virtProbeAbsent),
      },
      // Found but refused: it is a host, and the host's own page says what to
      // change. Not reached in practice — a found server is a host — but a
      // row has to say something.
      VirtProbeStatus.found => const Icon(Icons.check, size: 15),
      VirtProbeStatus.failed => Tooltip(
        message: [
          probe!.error?.title ?? libL10n.error,
          ?probe.error?.detail,
        ].join('\n'),
        child: Icon(
          Icons.error_outline,
          size: 15,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    };
  }
}
