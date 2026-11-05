// ignore_for_file: invalid_use_of_protected_member

part of 'view.dart';

extension _Actions on _SshDiscoveryViewState {
  /// Runs [source] with what it was given: its token, or the picked file.
  Future<void> _run(SshDiscovery source) async {
    if (!mounted) return;
    final st = _states[source.id]!;
    if (st.phase == _Phase.running) return;
    setState(() => st.phase = _Phase.running);
    try {
      final run = await source.discover(
        input: source.credential == null ? st.file : st.token.text,
      );
      if (!mounted) return;
      final found = {
        for (final h in run.hosts) _SshDiscoveryViewState._keyOf(source, h),
      };
      setState(() {
        st
          ..hosts = run.hosts
          ..scope = run.scope ?? st.scope
          ..error = null
          ..phase = _Phase.done;
        // A host gone from this source's list cannot stay checked unseen.
        _selected.removeWhere(
          (key, _) => key.startsWith('${source.id}/') && !found.contains(key),
        );
      });
    } on SshDiscoveryException catch (e) {
      if (!mounted) return;
      setState(() {
        st
          ..error = e
          ..phase = _Phase.failed;
      });
    } catch (e, s) {
      Loggers.app.warning('Discovery ${source.id}', e, s);
      if (!mounted) return;
      setState(() {
        st
          ..error = SshDiscoveryException(l10n.discoveryFailed, tip: '$e')
          ..phase = _Phase.failed;
      });
    }
  }

  /// A source asking for a token goes back to its field; one that runs by
  /// itself runs again.
  void _retry(SshDiscovery source) {
    final st = _states[source.id]!;
    if (source.credential != null) {
      setState(() => st.phase = _Phase.idle);
      return;
    }
    _run(source);
  }

  Future<void> _pickFile(SshDiscovery source) async {
    final picked = await FilePicker.pickFile(
      type: FileType.any,
      dialogTitle: source.label,
    );
    if (picked?.path case final path?) {
      _states[source.id]!.file = path;
      await _run(source);
    }
  }

  /// Forgets the token and what it found.
  void _disconnect(SshDiscovery source) {
    final st = _states[source.id]!;
    setState(() {
      st
        ..token.clear()
        ..hosts = const []
        ..phase = _Phase.idle;
      _selected.removeWhere((key, _) => key.startsWith('${source.id}/'));
    });
  }

  /// Adds every checked host with the servers it jumps through, and this
  /// device when checked. A host or hop that is a server already is not
  /// added again: the jumps that named it point at that server instead.
  Future<void> _addSelected() async {
    setState(() => _adding = true);
    final notifier = ref.read(serversProvider.notifier);
    // Read now rather than trusted from the last build: the servers may have
    // loaded, or a sync landed, since the boxes were checked.
    final existing = ref.read(serversProvider).servers.values.toList();
    var added = 0;
    try {
      if (_selfSelected) {
        _selfSelected = false;
        if (!existing.any((e) => e.local) &&
            await _add(
              notifier,
              Spi(
                name: Platform.localHostname,
                id: ShortId.generate(),
                local: true,
              ),
            )) {
          _selfAdded = true;
          added++;
        }
      }

      final plan = planDiscoveredServers(_selected.values, existing);
      // A server whose hop could not be added is not added either: its jump
      // would name a server that is not there.
      final failed = <String>{};
      for (final spi in plan.add) {
        final ok =
            !(spi.ssh?.resolvedJumpIds.any(failed.contains) ?? false) &&
            await _add(notifier, spi);
        if (ok) {
          added++;
        } else {
          failed.add(spi.id);
        }
      }
      for (final entry in _selected.entries.toList()) {
        if (failed.contains(plan.ids[entry.value.server.id])) continue;
        _selected.remove(entry.key);
        _added.add(entry.key);
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

/// What adding [hosts] takes: [add], each host after its hops, none twice
/// and none already in [existing], with every jump pointed at the server that
/// will be there and names made unique; and [ids], where each original id
/// ends up.
({List<Spi> add, Map<String, String> ids}) planDiscoveredServers(
  Iterable<DiscoveredSshHost> hosts,
  List<Spi> existing,
) {
  final ids = <String, String>{};
  final fresh = <Spi>[];
  void take(Spi spi, {required bool user}) {
    if (ids.containsKey(spi.id)) return;
    final same =
        existing.firstWhereOrNull(
          (e) => DiscoveredSshHost.sameHost(spi, e, user: user),
        ) ??
        fresh.firstWhereOrNull(
          (e) => DiscoveredSshHost.sameHost(spi, e, user: user),
        );
    if (same != null) {
      ids[spi.id] = same.id;
    } else {
      ids[spi.id] = spi.id;
      fresh.add(spi);
    }
  }

  for (final h in hosts) {
    // Hops come from a file that names their accounts.
    for (final hop in h.via) {
      take(hop, user: true);
    }
    take(h.server, user: h.userKnown);
  }
  final pointed = [
    for (final spi in fresh)
      switch (spi.ssh) {
        final ssh? when ssh.resolvedJumpIds.isNotEmpty => spi.copyWith(
          ssh: ssh.copyWith(
            jumpId: null,
            jumpIds: [for (final id in ssh.resolvedJumpIds) ids[id] ?? id],
          ),
        ),
        _ => spi,
      },
  ];
  return (
    add: ServerDeduplication.resolveNameConflicts(
      pointed,
      existingServers: existing,
    ),
    ids: ids,
  );
}
