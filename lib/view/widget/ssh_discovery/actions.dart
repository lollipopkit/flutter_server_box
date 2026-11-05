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
  /// device when checked.
  ///
  /// First the hosts reached directly are told apart by host key: one whose
  /// key and account are a server's already is not added, and one account
  /// checked at several addresses becomes one server, its other address the
  /// alternate, as the user picks.
  Future<void> _addSelected() async {
    setState(() => _adding = true);
    final notifier = ref.read(serversProvider.notifier);
    var added = 0;
    try {
      if (_selfSelected) {
        _selfSelected = false;
        final hasLocal = ref
            .read(serversProvider)
            .servers
            .values
            .any((e) => e.local);
        if (!hasLocal &&
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

      final merged = await _mergeByHostKey();
      if (merged == null || !mounted) return;

      // Read now, after the probes and the dialog: a sync may have landed
      // meanwhile.
      final existing = ref.read(serversProvider).servers.values.toList();
      final plan = planDiscoveredServers(merged.hosts.values, existing);
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
      for (final MapEntry(:key, value: h) in merged.hosts.entries) {
        if (failed.contains(plan.ids[h.server.id])) continue;
        // Its other addresses went into it, and are done with it.
        for (final k in [key, ...?merged.into[key]]) {
          _selected.remove(k);
          _added.add(k);
        }
      }
    } finally {
      if (mounted) setState(() => _adding = false);
      if (added > 0) Toast.success(l10n.discoveryAddedN(added));
    }
  }

  /// [_selected] with each account on one machine once, keyed as it was, and
  /// what [into] which key went. A host already a server leaves the
  /// selection, marked as one. Null when the user dismissed the choice of
  /// addresses, or the view went away.
  Future<
    ({Map<String, DiscoveredSshHost> hosts, Map<String, List<String>> into})?
  >
  _mergeByHostKey() async {
    final selected = Map.of(_selected);
    final servers = {
      for (final e in ref.read(serversProvider).servers.values) e.id: e,
    };
    // Only what is reached directly: a hop or a ProxyCommand stands between
    // this device and the key.
    final direct = <String, SshCredential>{};
    for (final MapEntry(:key, value: h) in selected.entries) {
      final ssh = h.server.ssh;
      if (h.via.isNotEmpty || ssh == null) continue;
      if (ssh.proxyCommand != null || ssh.resolvedJumpIds.isNotEmpty) continue;
      direct[key] = ssh;
    }
    final known = loadKnownHostFingerprints();
    final storedTypes = hostKeyTypesOf(known, servers.keys.toSet());
    // Nothing to compare one key with.
    if (direct.length < 2 && storedTypes.isEmpty) {
      return (hosts: selected, into: const <String, List<String>>{});
    }

    final probe = widget.probe ?? probeHostKey;
    final keys = await _pool(direct, (ssh) async {
      final id = await probe(ssh);
      if (id == null) return null;
      return [
        id,
        // The type a server here was trusted with, when it is not this one.
        for (final type in storedTypes)
          if (type != id.type) await probe(ssh, prefer: type),
      ].nonNulls.toList();
    });
    if (keys == null || !mounted) return null;

    final grouped = groupByHostKey(
      {
        for (final MapEntry(:key, value: ids) in keys.entries)
          if (ids != null && ids.isNotEmpty)
            key: (
              ids: ids,
              user: selected[key]!.userKnown ? direct[key]!.user : null,
            ),
      },
      known,
      servers,
    );
    for (final key in grouped.known) {
      selected.remove(key);
      _selected.remove(key);
      _known.add(key);
    }
    final into = <String, List<String>>{};
    if (grouped.groups.isEmpty) return (hosts: selected, into: into);

    // The first source listed leads by default.
    int order(String key) =>
        _sources.indexWhere((s) => key.startsWith('${s.id}/'));
    for (final group in grouped.groups) {
      group.sort((a, b) => order(a).compareTo(order(b)));
    }
    final choices = await _SameMachineDialog.show(context, [
      for (final group in grouped.groups)
        (
          fingerprint: keys[group.first]!.first.fingerprint,
          hosts: [
            for (final key in group)
              (label: _labelOf(key), host: selected[key]!),
          ],
        ),
    ]);
    if (choices == null || !mounted) return null;

    for (final (g, group) in grouped.groups.indexed) {
      final (:primary, :alternate) = choices[g];
      final main = selected[group[primary]]!;
      final alt = alternate == null ? null : selected[group[alternate]]!;
      into[group[primary]] = [
        for (final (i, key) in group.indexed)
          if (i != primary) key,
      ];
      for (final key in into[group[primary]]!) {
        selected.remove(key);
      }
      // The account is whichever entry named it; the group shares one.
      final named = group.map((k) => selected[k] ?? _selected[k]!).firstWhereOrNull(
        (h) => h.userKnown,
      );
      final user = (named ?? main).server.ssh!.user;
      selected[group[primary]] = main.withServer(
        main.server.copyWith(
          ssh: main.server.ssh!.copyWith(
            user: user,
            alterUrl: alt == null ? null : '$user@${alt.host}:${alt.port}',
          ),
        ),
      );
    }
    return (hosts: selected, into: into);
  }

  /// [work] for each of [items], 16 at a time; null when the view went away
  /// before it finished.
  Future<Map<String, R>?> _pool<T, R>(
    Map<String, T> items,
    Future<R> Function(T) work,
  ) async {
    final out = <String, R>{};
    final queue = items.entries.toList();
    var next = 0;
    Future<void> worker() async {
      while (mounted && next < queue.length) {
        final e = queue[next++];
        out[e.key] = await work(e.value);
      }
    }

    await Future.wait([for (var i = 0; i < 16; i++) worker()]);
    return mounted ? out : null;
  }

  /// The source a selection key came from, by its label.
  String _labelOf(String key) {
    final id = key.substring(0, key.indexOf('/'));
    return _sources.firstWhereOrNull((s) => s.id == id)?.label ?? id;
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

/// The selection keys whose host key and account are a server's already
/// ([known]), and the rest grouped where they are one account on one machine.
///
/// [keys] holds each host's keys, of every type probed, and its account when
/// the source named one. One host key is one machine; on it, two named
/// accounts are two servers, and an unnamed one joins the first named.
@visibleForTesting
({Set<String> known, List<List<String>> groups}) groupByHostKey(
  Map<String, ({List<HostKeyId> ids, String? user})> keys,
  Map<String, String> knownHosts,
  Map<String, Spi> servers,
) {
  final known = <String>{};
  final byMachine = <String, List<String>>{};
  for (final MapEntry(:key, value: (:ids, :user)) in keys.entries) {
    final matches = {
      for (final id in ids)
        ...serversWithHostKey(id, knownHosts, servers.keys.toSet()),
    };
    if (matches.any((id) => user == null || servers[id]?.ssh?.user == user)) {
      known.add(key);
      continue;
    }
    final first = ids.first;
    (byMachine['${first.type} ${first.fingerprint}'] ??= []).add(key);
  }

  final groups = <List<String>>[];
  for (final machine in byMachine.values) {
    final byUser = <String, List<String>>{};
    final unnamed = <String>[];
    for (final key in machine) {
      final user = keys[key]!.user;
      user == null ? unnamed.add(key) : (byUser[user] ??= []).add(key);
    }
    final accounts = byUser.values.toList();
    if (accounts.isEmpty) {
      accounts.add(unnamed);
    } else {
      accounts.first.addAll(unnamed);
    }
    groups.addAll(accounts.where((g) => g.length > 1));
  }
  return (known: known, groups: groups);
}

/// What adding [hosts] takes: [add], each host after its hops, none twice
/// and none already in [existing], with every jump pointed at the server that
/// will be there and names made unique; and [ids], where each original id
/// ends up.
///
/// "Already there" is an address a server connects to, its alternate
/// included: a hop at the address merged into another server is that server.
({List<Spi> add, Map<String, String> ids}) planDiscoveredServers(
  Iterable<DiscoveredSshHost> hosts,
  List<Spi> existing,
) {
  final ids = <String, String>{};
  final fresh = <Spi>[];
  bool reaches(Spi server, Spi spi, {required bool user}) {
    if (DiscoveredSshHost.sameHost(spi, server, user: user)) return true;
    final ssh = server.ssh, other = spi.ssh;
    if (ssh?.alterUrl == null || other == null) return false;
    try {
      final (ip, usr, port) = ssh!.parseAlterUrl();
      return ip == other.ip &&
          port == other.port &&
          (!user || usr == other.user);
    } catch (_) {
      return false;
    }
  }

  void take(Spi spi, {required bool user}) {
    if (ids.containsKey(spi.id)) return;
    final same =
        existing.firstWhereOrNull((e) => reaches(e, spi, user: user)) ??
        fresh.firstWhereOrNull((e) => reaches(e, spi, user: user));
    if (same != null) {
      ids[spi.id] = same.id;
    } else {
      ids[spi.id] = spi.id;
      fresh.add(spi);
    }
  }

  // The hosts before their hops, so a hop at a merged-away address finds the
  // server it was merged into.
  for (final h in hosts) {
    take(h.server, user: h.userKnown);
  }
  for (final h in hosts) {
    // Hops come from a file that names their accounts.
    for (final hop in h.via) {
      take(hop, user: true);
    }
  }
  // Hops first in the order they are added: a server's jump must exist.
  final hopIds = {
    for (final h in hosts)
      for (final hop in h.via) ids[hop.id],
  };
  final ordered = [
    ...fresh.where((e) => hopIds.contains(e.id)),
    ...fresh.where((e) => !hopIds.contains(e.id)),
  ];
  final pointed = [
    for (final spi in ordered)
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
