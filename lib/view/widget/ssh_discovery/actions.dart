// ignore_for_file: invalid_use_of_protected_member

part of 'view.dart';

extension _Actions on _SshDiscoveryViewState {
  Future<void> _scan(SshDiscovery source) async {
    final st = _states[source.id]!;
    setState(() => st.phase = _Phase.scanning);
    try {
      final hosts = await source.discover();
      if (!mounted) return;
      final found = hosts.map((h) => h.address).toSet();
      setState(() {
        st
          ..hosts = hosts
          ..phase = _Phase.done;
        // A host gone from this source's list cannot stay checked unseen.
        _selected.removeWhere(
          (key, _) => !found.contains(key) && !_inOtherSource(source, key),
        );
      });
    } catch (e, s) {
      Loggers.app.warning('Discovery ${source.id}', e, s);
      if (!mounted) return;
      setState(() => st.phase = _Phase.idle);
      Toast.error(l10n.discoveryFailed, body: '$e');
    }
  }

  bool _inOtherSource(SshDiscovery source, String key) => _states.entries.any(
    (e) => e.key != source.id && e.value.hosts.any((h) => h.address == key),
  );

  /// Adds every checked host, and this device when checked; each one that
  /// fails stays checked.
  Future<void> _addSelected() async {
    setState(() => _adding = true);
    final notifier = ref.read(serversProvider.notifier);
    // Read now rather than trusted from the last build: the servers may have
    // loaded, or a sync landed, since the boxes were checked.
    final servers = ref.read(serversProvider).servers.values;
    var added = 0;
    try {
      if (_selfSelected && servers.any((e) => e.local)) {
        _selfSelected = false;
      } else if (_selfSelected) {
        if (await _add(
          notifier,
          Spi(name: Platform.localHostname, id: ShortId.generate(), local: true),
        )) {
          _selfSelected = false;
          _selfAdded = true;
          added++;
        }
      }
      for (final h in _selected.values.toList()) {
        if (servers.any((e) => _isHost(e, h))) {
          _selected.remove(h.address);
          continue;
        }
        final spi = Spi(
          name: h.name ?? h.host,
          id: ShortId.generate(),
          ssh: SshCredential(ip: h.host, port: h.port, user: h.user ?? 'root'),
        );
        if (await _add(notifier, spi)) {
          _selected.remove(h.address);
          _added.add(h.address);
          added++;
        }
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
    if (added > 0) Toast.success(l10n.discoveryAddedN(added));
  }

  Future<bool> _add(ServersNotifier notifier, Spi spi) async {
    try {
      await notifier.addServer(spi);
      return true;
    } catch (e, s) {
      Loggers.app.warning('Add a discovered server', e, s);
      Toast.error(libL10n.fail, body: '$e');
      return false;
    }
  }
}
