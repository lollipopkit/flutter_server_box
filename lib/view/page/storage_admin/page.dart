import 'dart:async';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/admin/storage_manager.dart';
import 'package:server_box/data/admin/user_manager.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/storage.dart';
import 'package:server_box/data/model/server/sudo_error.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/storage_admin/helpers.dart';
import 'package:server_box/view/widget/pullable_issue.dart';

enum _StorageTab { disks, raid, zfs }

final class StoragePage extends ConsumerStatefulWidget {
  const StoragePage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: StoragePage.new,
    path: '/storage',
  );

  @override
  ConsumerState<StoragePage> createState() => _StoragePageState();
}

final class _StoragePageState extends ConsumerState<StoragePage> {
  late final _provider = serverProvider(widget.args.spi.id);
  StorageView? _view;
  List<DiskHealth> _health = [];
  _StorageTab _tab = _StorageTab.disks;
  bool _busy = false;
  bool _isRoot = false;
  bool _healthTried = false;
  bool _healthLocked = false;
  String? _failure;
  Timer? _poll;
  Timer? _healthPoll;
  Future<void> _rootLookup = Future<void>.value();

  void _rebuild(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _healthPoll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linux = ref.watch(
      _provider.select((state) => state.status.system == SystemType.linux),
    );
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: l10n.storageTitle, down: widget.args.spi.name),
        actions: [
          if (isDesktop)
            Btn.icon(
              text: libL10n.refresh,
              icon: const Icon(Icons.refresh, size: 18),
              onTap: _busy ? null : _refresh,
            ),
        ],
      ),
      body: !linux
          ? PageIssueView(
              title: libL10n.unsupported,
              explain: l10n.storageLinuxOnly,
              icon: Icons.not_interested,
              onRetry: _refresh,
            )
          : RefreshIndicator(onRefresh: _refresh, child: _body()),
      floatingActionButton: _tab == _StorageTab.raid && _has('mdadm')
          ? FloatingActionButton(
              tooltip: l10n.storageCreateRaid,
              onPressed: _busy ? null : _createRaid,
              child: const Icon(Icons.add),
            )
          : _tab == _StorageTab.zfs && _has('zpool')
          ? FloatingActionButton(
              tooltip: l10n.storageCreatePool,
              onPressed: _busy ? null : _createPool,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

extension on _StoragePageState {
  bool _has(String tool) => _view?.tools.contains(tool) ?? false;

  Widget _body() {
    if (_failure case final failure?) {
      return PullableIssueView(title: libL10n.fail, detail: failure, onRetry: _refresh);
    }
    final view = _view;
    if (view == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 280, child: UIs.centerLoading)],
      );
    }
    final disks = storageDisks(view);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 13, 13),
            child: SegmentedTabs<_StorageTab>(
              expand: true,
              segments: [
                SegmentedTab(value: _StorageTab.disks, label: l10n.storageDisks),
                SegmentedTab(value: _StorageTab.raid, label: l10n.storageRaid),
                SegmentedTab(value: _StorageTab.zfs, label: l10n.storagePools),
              ],
              selected: _tab,
              onSelected: (value) => _rebuild(() => _tab = value),
            ),
          ),
        ),
        if (_busy) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 90),
          sliver: SliverList.list(
            children: switch (_tab) {
              _StorageTab.disks => [
                Row(
                  children: [
                    Text(l10n.storageDisks, style: UIs.text11Grey),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _readHealth(),
                      icon: Icon(
                        _healthLocked ? Icons.lock_outline : Icons.health_and_safety,
                        size: 17,
                      ),
                      label: Text(l10n.storageHealthRead),
                    ),
                  ],
                ),
                if (disks.isEmpty)
                  _empty(Icons.storage, l10n.storageNoDisks)
                else
                  for (final disk in disks) _diskCard(view, disk),
              ],
              _StorageTab.raid => [
                if (!_has('mdadm')) _notice(l10n.storageNoMdadm),
                if (view.arrays.isEmpty)
                  _empty(Icons.view_in_ar, l10n.storageNoArrays)
                else
                  for (final array in view.arrays) _raidCard(view, array),
              ],
              _StorageTab.zfs => [
                if (!_has('zpool')) _notice(l10n.storageNoZfs),
                if (view.pools.isEmpty)
                  _empty(Icons.storage, l10n.storageNoPools)
                else
                  for (final pool in view.pools) _poolCard(view, pool),
              ],
            },
          ),
        ),
      ],
    );
  }

  Widget _diskCard(StorageView view, BlockDevice disk) {
    final health = _health.firstWhereOrNull((h) => h.device == disk.path);
    final busy = view.busy[disk.path];
    final volumes = storageVolumes(disk);
    return CardX(
      margin: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text('${disk.model ?? disk.name} · ${_bytes(disk.size)}'),
            subtitle: Text(
              [
                disk.path,
                disk.transport?.toUpperCase(),
                disk.rotational ? 'HDD' : 'SSD',
                disk.serial,
              ].whereType<String>().join(' · '),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (busy != null) _badge(_busyText(busy)),
                if (health != null) _badge(_healthText(health)),
              ],
            ),
          ),
          for (final volume in volumes) _volume(view, volume, disk),
          if (health != null && health.supported)
            ListTile(
              dense: true,
              title: Text(_healthFacts(health), style: UIs.text12Grey),
              subtitle: health.lastTest == null
                  ? null
                  : Text(_testText(health.lastTest!), style: UIs.text11Grey),
              trailing: IconButton(
                tooltip: l10n.storageDetails,
                icon: const Icon(Icons.monitor_heart_outlined),
                onPressed: () => _showHealth(health),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 9),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 5,
              children: [
                if (health?.supported == true)
                  TextButton(
                    onPressed: _busy || health!.testing != null
                        ? null
                        : () => _runAction(
                            StorageAction.smartTest(device: disk.path, long: false),
                            l10n.storageSmartTest,
                            l10n.storageSmartTestBody(disk.path),
                          ),
                    child: Text(l10n.storageSmartTest),
                  ),
                if (busy == null && _has('sfdisk'))
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _runAction(
                            StorageAction.partition(device: disk.path),
                            l10n.storageInitialize,
                            l10n.storageInitializeBody(disk.path),
                            confirmWord: disk.path,
                          ),
                    child: Text(l10n.storageInitialize),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _volume(StorageView view, BlockDevice volume, BlockDevice disk) {
    final opened = volume.fstype == 'crypto_LUKS'
        ? volume.children.firstWhereOrNull((d) => d.kind == 'crypt')
        : null;
    final mounted = volume.mounted;
    final busy = view.busy[volume.path];
    final facts = volume.fstype == 'crypto_LUKS'
        ? [l10n.storageEncrypted, if (opened == null) l10n.storageLocked]
        : [
            volume.fstype,
            volume.label,
            if (mounted) volume.mountpoints.join(', '),
          ].whereType<String>().toList();
    final row = ListTile(
      dense: true,
      title: Text(volume.path, style: const TextStyle(fontFamily: 'monospace')),
      subtitle: Text(facts.isEmpty ? l10n.storageNoFilesystem : facts.join(' · ')),
      trailing: Wrap(
        spacing: 2,
        children: [
          if (view.system.contains(volume.path) || busy == 'systemPartition')
            _badge(l10n.storageBusySystem)
          else if (busy != null)
            _badge(_busyText(busy)),
          if (opened != null)
            IconButton(
              tooltip: l10n.storageLock,
              icon: const Icon(Icons.lock_outline),
              onPressed: _busy
                  ? null
                  : () => _runAction(
                      StorageAction.lock(device: volume.path),
                      l10n.storageLock,
                      l10n.storageLockBody(volume.path),
                    ),
            )
          else if (volume.fstype == 'crypto_LUKS' && _has('cryptsetup'))
            IconButton(
              tooltip: l10n.storageUnlock,
              icon: const Icon(Icons.lock_open),
              onPressed: _busy ? null : () => _unlock(volume),
            ),
          if ((_view?.growablePartitions.contains(volume.path) ?? false) && _has('sfdisk'))
            IconButton(
              tooltip: l10n.storageGrowPartition,
              icon: const Icon(Icons.open_in_full),
              onPressed: _busy
                  ? null
                  : () => _runAction(
                      StorageAction.growPartition(device: volume.path),
                      l10n.storageGrowPartition,
                      l10n.storageGrowPartitionBody(volume.path),
                    ),
            ),
          if (volume.mountpoints.isNotEmpty &&
              mounted &&
              !view.system.contains(volume.path) &&
              busy != 'systemPartition')
            IconButton(
              tooltip: l10n.storageUnmount,
              icon: const Icon(Icons.eject),
              onPressed: _busy
                  ? null
                  : () => _runAction(
                      StorageAction.unmount(mountpoint: volume.mountpoints.first),
                      l10n.storageUnmount,
                      l10n.storageUnmountBody(volume.mountpoints.first),
                    ),
            )
          else if (busy == null && volume.mountable)
            IconButton(
              tooltip: l10n.storageMount,
              icon: const Icon(Icons.folder_open),
              onPressed: _busy ? null : () => _mount(volume),
            ),
          if (volume.expandable)
            IconButton(
              tooltip: l10n.storageExpand,
              icon: const Icon(Icons.expand),
              onPressed: _busy
                  ? null
                  : () => _runAction(
                      StorageAction.expandFilesystem(device: volume.path),
                      l10n.storageExpand,
                      l10n.storageExpandBody(volume.path),
                    ),
            ),
          if (busy == null)
            IconButton(
              tooltip: l10n.storageFormat,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _busy ? null : () => _format(volume),
            ),
        ],
      ),
    );
    return Column(
      children: [
        row,
        if (opened != null) _volume(view, opened, disk),
        Divider(height: 1, color: Hairline.color(context)),
      ],
    );
  }

  Widget _raidCard(StorageView view, MdArray array) {
    final degraded = array.degraded;
    final device = storageArrayDevice(view, array.name);
    return CardX(
      margin: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text('/dev/${array.name} · ${array.level ?? array.state}'),
            subtitle: Text('${l10n.storageState}: ${array.state}'),
            trailing: _badge(
              array.state != 'active'
                  ? array.state
                  : degraded
                  ? l10n.storageDegraded
                  : l10n.storageHealthy,
            ),
          ),
          if (device != null) _volume(view, device, device),
          if (array.sync_ != null)
            ListTile(
              dense: true,
              title: Text(l10n.storageSync(array.sync_!.action)),
              subtitle: LinearProgressIndicator(
                value: array.sync_!.permille / 1000,
              ),
              trailing: Text('${(array.sync_!.permille / 10).toStringAsFixed(1)}%'),
            ),
          for (final member in array.members)
            ListTile(
              dense: true,
              title: Text('/dev/${member.name}'),
              subtitle: Text(
                member.faulty
                    ? l10n.storageFaulty
                    : member.spare
                    ? l10n.storageSpare
                    : l10n.storageActive,
              ),
              trailing: IconButton(
                tooltip: l10n.storageRemoveMember,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _busy
                    ? null
                    : () => _runAction(
                        StorageAction.removeFromRaid(array: array.name, device: '/dev/${member.name}'),
                        l10n.storageRemoveMember,
                        l10n.storageRemoveMemberBody(
                          array.name,
                          '/dev/${member.name}',
                        ),
                        confirmWord: storageShortName('/dev/${member.name}'),
                      ),
              ),
            ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _runAction(
                        StorageAction.deleteRaid(array: array.name),
                        l10n.storageDeleteRaid,
                        l10n.storageDeleteRaidBody(array.name),
                        confirmWord: array.name,
                      ),
                child: Text(l10n.storageDeleteRaid),
              ),
              if (array.growable)
                TextButton(
                  onPressed: _busy ? null : () => _pickDevice(array, grow: true),
                  child: Text(l10n.storageGrowRaid),
                ),
              TextButton.icon(
                onPressed: _busy ? null : () => _pickDevice(array),
                icon: const Icon(Icons.add),
                label: Text(l10n.storageAddMember),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _poolCard(StorageView view, Pool pool) {
    return CardX(
      margin: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text('${pool.name} · ${_bytes(pool.size)}'),
            subtitle: Text(
              '${l10n.storageUsage(_bytes(pool.size), _bytes(pool.allocated))} · ${l10n.storageFree(_bytes(pool.free))}',
            ),
            trailing: _badge(pool.health),
          ),
          if (pool.scan case final scan?)
            ListTile(dense: true, title: Text(l10n.storageScan), subtitle: Text(scan)),
          for (final (index, vdev) in pool.vdevs.indexed)
            _poolDevice(pool, vdev, index),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _runAction(
                        StorageAction.destroyPool(name: pool.name),
                        l10n.storageDestroyPool,
                        l10n.storageDestroyPoolBody(pool.name),
                        confirmWord: pool.name,
                      ),
                child: Text(l10n.storageDestroyPool),
              ),
              TextButton(
                onPressed: _busy ? null : () => _pickPoolDevice(pool),
                child: Text(l10n.storageAddSpare),
              ),
              TextButton(
                onPressed: _busy ? null : () => _createPoolVdev(pool),
                child: Text(l10n.storageAddToPool),
              ),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runAction(
                        StorageAction.scrubPool(name: pool.name),
                        l10n.storageScrub,
                        l10n.storageScrubBody(pool.name),
                      ),
                icon: const Icon(Icons.cleaning_services),
                label: Text(l10n.storageScrub),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _poolDevice(Pool pool, Vdev device, int index) {
    final can = pool.vdevs[index].actions;
    final title = '${'  ' * (device.depth + (device.section == null ? 0 : 1))}${device.name}';
    return ListTile(
      dense: true,
      title: Text(title, style: const TextStyle(fontFamily: 'monospace')),
      subtitle: Text(
        [device.section, device.state, if (device.errors > BigInt.zero) l10n.storageErrors(device.errors.toInt())]
            .whereType<String>()
            .join(' · '),
      ),
      trailing: Wrap(
        spacing: 0,
        children: [
          if (can.online)
            IconButton(
              tooltip: l10n.storageOnline,
              icon: const Icon(Icons.link),
              onPressed: _busy
                  ? null
                  : () => _runAction(
                      StorageAction.onlineInPool(name: pool.name, device: device.name),
                      l10n.storageOnline,
                      l10n.storageOnlineBody(device.name, pool.name),
                    ),
            ),
          if (can.replace)
            IconButton(
              tooltip: l10n.storageReplace,
              icon: const Icon(Icons.swap_horiz),
              onPressed: _busy
                  ? null
                  : () => _pickReplacement(pool, device.name),
            ),
          if (can.attach)
            IconButton(
              tooltip: l10n.storageAttach,
              icon: const Icon(Icons.call_merge),
              onPressed: _busy
                  ? null
                  : () => _pickAttach(pool, device.name),
            ),
          if (can.remove)
            IconButton(
              tooltip: l10n.storageRemoveDevice,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _busy
                  ? null
                  : () => _runAction(
                      StorageAction.removeFromPool(name: pool.name, device: device.name),
                      l10n.storageRemoveDevice,
                      l10n.storageRemoveDeviceBody(device.name, pool.name),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text) => Chip(
    label: Text(text, style: const TextStyle(fontSize: 11)),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _notice(String text) => CardX(
    margin: const EdgeInsets.only(bottom: 11),
    child: ListTile(leading: const Icon(Icons.info_outline), title: Text(text)),
  );

  Widget _empty(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 70),
    child: Column(
      children: [Icon(icon, size: 45, color: UIs.textGrey.color), Text(text)],
    ),
  );

  String _bytes(BigInt bytes) => ReadingFmt.size(bytes.toDouble());

  String _busyText(String code) => switch (code) {
    'mounted' => l10n.storageBusyMounted,
    'swap' => l10n.storageBusySwap,
    'raidMember' => l10n.storageBusyRaid,
    'poolMember' => l10n.storageBusyPool,
    'lvmMember' || 'holdsVolume' => l10n.storageBusyVolume,
    'readOnly' => l10n.storageBusyReadOnly,
    'systemPartition' => l10n.storageBusySystem,
    _ => code,
  };

  String _healthText(DiskHealth health) => switch (health.verdict) {
    HealthVerdict.asleep => l10n.storageHealthAsleep,
    HealthVerdict.unsupported => l10n.storageHealthUnsupported,
    HealthVerdict.failing => l10n.storageHealthFailing,
    HealthVerdict.wearing => l10n.storageHealthWearing,
    HealthVerdict.healthy => l10n.storageHealthy,
  };

  String _healthFacts(DiskHealth health) => [
    if (health.testing != null) l10n.storageTesting(health.testing!),
    if (health.temperature != null) l10n.storageTemperature(health.temperature!),
    if (health.powerOnHours != null) l10n.storagePowerOn(health.powerOnHours!),
    if (health.badSectors != null && health.badSectors! > 0)
      l10n.storageBadSectors(health.badSectors!),
  ].join(' · ');

  String _testText(SelfTest test) => [
    test.long ? l10n.storageTestLong : l10n.storageTestShort,
    switch (test.outcome) {
      'passed' => l10n.storageTestPassed,
      'failed' => l10n.storageTestFailed,
      _ => l10n.storageTestAborted,
    },
    if (test.hours != null) l10n.storageAtHours(test.hours!),
  ].join(' · ');

  Future<CommandExec> _exec() => ref.read(_provider.notifier).ensureExec();

  Future<void> _refresh() async {
    if (_busy || !mounted) return;
    _rebuild(() {
      _busy = true;
      _failure = null;
    });
    try {
      final exec = await _exec();
      final next = await StorageManager.view(exec);
      if (!mounted) return;
      _rebuild(() {
        _view = next;
        _isRoot = widget.args.spi.isRoot;
      });
      _rootLookup = _resolveRoot(exec);
      _syncPoll();
      _syncHealthPoll();
      if (!_healthTried && next.tools.contains('smartctl')) {
        _healthTried = true;
        unawaited(_readHealth(quiet: true));
      }
    } catch (e, s) {
      Loggers.app.warning('Read storage on ${widget.args.spi.id}', e, s);
      if (mounted) _rebuild(() => _failure = '$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }

  Future<void> _resolveRoot(CommandExec exec) async {
    try {
      final currentUser = (await UserManager.list(exec)).currentUser;
      if (mounted && currentUser == 'root' && !_isRoot) {
        _rebuild(() => _isRoot = true);
      }
    } catch (_) {
      // Root status from the configured connection remains the fallback.
    }
  }

  void _disposeAfterExit(List<TextEditingController> controllers) {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  void _syncHealthPoll() {
    _healthPoll?.cancel();
    if (_healthLocked || !_health.any((item) => item.testing != null)) {
      _healthPoll = null;
      return;
    }
    _healthPoll = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _readHealth(quiet: true),
    );
  }

  void _syncPoll() {
    final view = _view;
    final active = view != null &&
        (view.arrays.any((array) => array.sync_ != null) ||
            view.pools.any((pool) => pool.scanning));
    _poll?.cancel();
    _poll = active ? Timer.periodic(const Duration(seconds: 3), (_) => _refresh()) : null;
  }

  Future<void> _readHealth({bool quiet = false}) async {
    final view = _view;
    if (view == null) return;
    try {
      await _rootLookup;
      if (!mounted) return;
      if (quiet) {
        final result = await StorageManager.health(
          await _exec(),
          isRoot: _isRoot,
        );
        if (mounted) {
          _rebuild(() {
            _health = result;
            _healthLocked = false;
          });
          _syncHealthPoll();
        }
        return;
      }
      final List<DiskHealth>? disks;
      try {
        disks = await SudoPassword.retryOnRejected(
          context,
          widget.args.spi.id,
          label: widget.args.spi.ssh?.user,
          attempt: (password) async => StorageManager.health(
            await _exec(),
            isRoot: _isRoot,
            password: password,
          ),
        );
      } on Exception catch (error) {
        if (error is! StorageFailure && error is! SudoRejected) rethrow;
        if (mounted) {
          _rebuild(() => _healthLocked = true);
          _healthPoll?.cancel();
          _healthPoll = null;
          _showActionError(error);
        }
        return;
      }
      if (disks case final disks? when mounted) {
        _rebuild(() {
          _health = disks;
          _healthLocked = false;
        });
        _syncHealthPoll();
      }
    } catch (e, s) {
      Loggers.app.warning('Read storage health on ${widget.args.spi.id}', e, s);
      if (quiet && e is SudoRejected) {
        if (mounted) _rebuild(() => _healthLocked = true);
      } else if (!quiet && mounted) {
        Toast.error('$e');
      }
    }
  }

  Future<void> _runAction(
    StorageAction action,
    String title,
    String body, {
    String? confirmWord,
    String? passphrase,
  }) async {
    if (_busy) return;
    final confirmed = await _confirmAction(title, body, confirmWord);
    if (!confirmed || !mounted) return;
    _rebuild(() => _busy = true);
    try {
      final bool? done;
      try {
        done = await SudoPassword.retryOnRejected(
          context,
          widget.args.spi.id,
          label: widget.args.spi.ssh?.user,
          attempt: (password) async {
            await StorageManager.act(
              await _exec(),
              action,
              isRoot: _isRoot,
              password: password,
              passphrase: passphrase,
            );
            return true;
          },
        );
      } on Exception catch (error) {
        if (error is! StorageFailure && error is! SudoRejected) rethrow;
        _showActionError(error);
        return;
      }
      if (done == null) return;
      if (mounted) Toast.success(libL10n.success);
      await _refreshAfterAction();
    } catch (e, s) {
      Loggers.app.warning('Storage action on ${widget.args.spi.id}', e, s);
      if (mounted) Toast.error('$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }

  void _showActionError(Exception error) {
    final message = switch (error) {
      StorageRefused(:final refusal) => switch (refusal.error) {
        'inUse' => l10n.storageInUse(refusal.device ?? ''),
        'busy' => l10n.storageBusy,
        'systemMount' => l10n.storageSystemMount,
        'notMounted' => l10n.storageNotMounted,
        'mounted' => l10n.storageMountedInside,
        'notRemovable' => l10n.storageNotRemovable,
        'notGrowable' => l10n.storageNotGrowable,
        'overlapping' => l10n.storageOverlapping,
        final code => code,
      },
      StorageInvalid(:final error) => switch (error) {
        StorageError.invalidDevice => l10n.storageInvalidDevice,
        StorageError.invalidMountpoint => l10n.storageInvalidMountpoint,
        StorageError.invalidName => l10n.storageInvalidName,
        StorageError.invalidFilesystem => l10n.storageInvalidFilesystem,
        StorageError.invalidLabel => l10n.storageInvalidLabel,
        StorageError.invalidLevel => l10n.storageInvalidLevel,
        StorageError.tooFewDevices => l10n.storageTooFewDevices,
        StorageError.keyRequired => l10n.storageKeyRequired,
        StorageError.invalidPassphrase => l10n.storageInvalidPassphrase,
      },
      _ => '$error',
    };
    Toast.error(message);
  }

  Future<void> _refreshAfterAction() async {
    if (mounted) _rebuild(() => _busy = false);
    await _refresh();
  }

  Future<bool> _confirmAction(
    String title,
    String body,
    String? confirmWord,
  ) async {
    final controller = TextEditingController();
    try {
      final ok = await context.showSheet<bool>(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(body),
            if (confirmWord != null) ...[
              const SizedBox(height: 8),
              Text(l10n.storageTypeToConfirm(confirmWord)),
              Input(controller: controller, autoFocus: true, suggestion: false),
            ],
          ],
        ),
        actions: confirmWord == null ? Btnx.cancelOk : Btnx.cancelRedOk,
      );
      final typed = confirmWord == null || controller.text.trim() == confirmWord;
      if (ok == true && !typed && mounted) {
        Toast.error(l10n.storageConfirmationMismatch);
      }
      return ok == true && typed;
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    }
  }

  Future<void> _format(BlockDevice device) async {
    final options = ['ext4', 'xfs', 'btrfs']
        .where((fs) => _has('mkfs.$fs'))
        .toList();
    if (options.isEmpty) return;
    var fs = options.first;
    var label = '';
    var encrypt = false;
    final controllers = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    final form = await context.showSheet<bool>(
      title: l10n.storageFormat,
      child: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.storageFormatBody(device.path)),
            DropdownButtonFormField<String>(
              initialValue: fs,
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (value) => setDialogState(() => fs = value ?? fs),
              decoration: InputDecoration(labelText: l10n.storageFilesystem),
            ),
            Input(controller: controllers[0], label: l10n.storageLabel),
            if (_has('cryptsetup'))
              CheckboxListTile(
                value: encrypt,
                title: Text(l10n.storageEncrypt),
                onChanged: (value) => setDialogState(() => encrypt = value ?? false),
              ),
            if (encrypt) ...[
              Input(
                controller: controllers[1],
                label: l10n.storagePassphrase,
                obscureText: true,
                hint: l10n.storagePassphraseHint,
              ),
              TextField(
                controller: controllers[2],
                decoration: InputDecoration(labelText: l10n.storagePassphraseAgain),
                obscureText: true,
              ),
            ],
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );
    label = controllers[0].text;
    final key = controllers[1].text;
    final repeated = controllers[2].text;
    _disposeAfterExit(controllers);
    if (form != true || !mounted) return;
    if (encrypt && key != repeated) {
      Toast.error(l10n.storagePassphrasesDiffer);
      return;
    }
    if (encrypt && key.length < 8) {
      Toast.error(l10n.storageInvalidPassphrase);
      return;
    }
    await _runAction(
      StorageAction.format(device: device.path, fstype: fs, label: label.trim().isEmpty ? null : label.trim(), encrypt: encrypt),
      l10n.storageFormat,
      l10n.storageFormatBody(device.path),
      confirmWord: device.path,
      passphrase: encrypt ? key : null,
    );
  }

  Future<void> _mount(BlockDevice device) async {
    final controller = TextEditingController(
      text: '/mnt/${(device.label ?? device.name).replaceAll(RegExp('[^A-Za-z0-9_.-]'), '-')}',
    );
    var persist = true;
    var own = true;
    final ok = await context.showSheet<bool>(
      title: l10n.storageMount,
      child: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(device.path),
            Input(controller: controller, label: l10n.storageMountpoint),
            CheckboxListTile(
              value: persist,
              title: Text(l10n.storageMountPersist),
              onChanged: (value) => setDialogState(() => persist = value ?? false),
            ),
            CheckboxListTile(
              value: own,
              title: Text(l10n.storageMountOwn),
              onChanged: (value) => setDialogState(() => own = value ?? false),
            ),
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );
    final mountpoint = controller.text.trim();
    _disposeAfterExit([controller]);
    if (ok != true || !mounted) return;
    await _runAction(
      StorageAction.mount(device: device.path, mountpoint: mountpoint, persist: persist, own: own),
      l10n.storageMount,
      l10n.storageMountBody(device.path, mountpoint),
    );
  }

  Future<void> _unlock(BlockDevice device) async {
    final controller = TextEditingController();
    final ok = await context.showSheet<bool>(
      title: l10n.storageUnlock,
      child: Input(
        controller: controller,
        label: l10n.storagePassphrase,
        obscureText: true,
      ),
      actions: Btnx.cancelOk,
    );
    final passphrase = controller.text;
    _disposeAfterExit([controller]);
    if (ok != true || !mounted) return;
    await _runAction(
      StorageAction.unlock(device: device.path),
      l10n.storageUnlock,
      l10n.storageUnlockBody(device.path),
      passphrase: passphrase,
    );
  }

  Future<void> _createRaid() async {
    final view = _view;
    if (view == null) return;
    final draft = await _createDraft(raid: true);
    if (draft == null || !mounted) return;
    await _runAction(
      StorageAction.createRaid(name: draft.name, level: int.parse(draft.layout), devices: draft.devices),
      l10n.storageCreateRaid,
      l10n.storageCreateRaidBody(draft.devices.join(', '), draft.layout, draft.name),
      confirmWord: draft.name,
    );
  }

  Future<void> _createPool() async {
    final draft = await _createDraft(raid: false);
    if (draft == null || !mounted) return;
    await _runAction(
      StorageAction.createPool(name: draft.name, layout: draft.layout, devices: draft.devices),
      l10n.storageCreatePool,
      l10n.storageCreatePoolBody(draft.devices.join(', '), draft.layout, draft.name),
      confirmWord: draft.name,
    );
  }

  Future<_CreateDraft?> _createDraft({
    required bool raid,
    String? poolName,
  }) async {
    final view = _view;
    if (view == null) return null;
    final free = _free(view);
    final name = TextEditingController(text: raid ? view.nextMd : poolName ?? 'tank');
    final choices = raid
        ? [for (final c in view.raidLevels) (value: '${c.value}', minimum: c.minimum)]
        : [for (final c in view.poolLayouts) (value: c.value, minimum: c.minimum)];
    int minimum(String value) =>
        choices.firstWhereOrNull((choice) => choice.value == value)?.minimum ?? 1;
    var layout = raid ? '1' : 'mirror';
    final selected = <String>{};
    final result = await context.showSheet<bool>(
      title: raid ? l10n.storageCreateRaid : l10n.storageCreatePool,
      child: StatefulBuilder(
        builder: (context, setDialogState) => SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (poolName == null)
                Input(controller: name, label: l10n.storageName),
              DropdownButtonFormField<String>(
                initialValue: layout,
                decoration: InputDecoration(labelText: raid ? l10n.storageLevel : l10n.storageLayout),
                items: [
                  for (final (:value, minimum: _) in choices)
                    DropdownMenuItem(value: value, child: Text(raid ? 'RAID $value' : value)),
                ],
                onChanged: (value) => setDialogState(() {
                  layout = value ?? layout;
                }),
              ),
              Text(l10n.storagePickDevices(minimum(layout))),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final device in free)
                      CheckboxListTile(
                        value: selected.contains(device.path),
                        title: Text('${device.path} · ${_bytes(device.size)}'),
                        onChanged: !selected.contains(device.path) &&
                                (view.overlaps[device.path] ?? const []).any(selected.contains)
                            ? null
                            : (value) => setDialogState(() {
                                if (value == true) {
                                  selected.add(device.path);
                                } else {
                                  selected.remove(device.path);
                                }
                              }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: Btnx.cancelOk,
    );
    final value = _CreateDraft(name.text.trim(), layout, selected.toList());
    _disposeAfterExit([name]);
    if (result != true || !mounted) return null;
    if (value.devices.length < minimum(layout) ||
        value.name.isEmpty) {
      Toast.error(l10n.storageTooFewDevices);
      return null;
    }
    return value;
  }

  List<BlockDevice> _free(StorageView view) => view.free.map(view.find).nonNulls.toList();

  Future<String?> _chooseDevice(String title, String message) async {
    final free = _view == null ? <BlockDevice>[] : _free(_view!);
    if (free.isEmpty) return null;
    var path = free.first.path;
    final ok = await context.showSheet<bool>(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          DropdownButtonFormField<String>(
            initialValue: path,
            items: [
              for (final device in free)
                DropdownMenuItem(
                  value: device.path,
                  child: Text('${device.path} · ${_bytes(device.size)}'),
                ),
            ],
            onChanged: (value) => path = value ?? path,
          ),
        ],
      ),
      actions: Btnx.cancelOk,
    );
    return ok == true ? path : null;
  }

  Future<void> _pickDevice(MdArray array, {bool grow = false}) async {
    final path = await _chooseDevice(
      grow ? l10n.storageGrowRaid : l10n.storageAddMember,
      '/dev/${array.name}',
    );
    if (path == null || !mounted) return;
    await _runAction(
      grow
          ? StorageAction.growRaid(array: array.name, device: path)
          : StorageAction.addToRaid(array: array.name, device: path),
      grow ? l10n.storageGrowRaid : l10n.storageAddMember,
      grow
          ? l10n.storageGrowRaidBody(array.name, path)
          : l10n.storageAddMemberBody(array.name, path),
      confirmWord: path,
    );
  }

  Future<void> _pickPoolDevice(Pool pool) async {
    final path = await _chooseDevice(l10n.storageAddSpare, pool.name);
    if (path == null || !mounted) return;
    await _runAction(
      StorageAction.addSpare(name: pool.name, devices: [path]),
      l10n.storageAddSpare,
      l10n.storageAddSpareBody(path, pool.name),
      confirmWord: path,
    );
  }

  Future<void> _createPoolVdev(Pool pool) async {
    final draft = await _createDraft(raid: false, poolName: pool.name);
    if (draft == null || !mounted) return;
    await _runAction(
      StorageAction.addToPool(name: pool.name, layout: draft.layout, devices: draft.devices),
      l10n.storageAddToPool,
      l10n.storageAddToPoolBody(draft.devices.join(', '), draft.layout, pool.name),
      confirmWord: pool.name,
    );
  }

  Future<void> _pickReplacement(Pool pool, String old) async {
    final path = await _chooseDevice(l10n.storageReplace, old);
    if (path == null || !mounted) return;
    await _runAction(
      StorageAction.replaceInPool(name: pool.name, old: old, new_: path),
      l10n.storageReplace,
      l10n.storageReplaceBody(pool.name, old, path),
      confirmWord: path,
    );
  }

  Future<void> _pickAttach(Pool pool, String existing) async {
    final path = await _chooseDevice(l10n.storageAttach, existing);
    if (path == null || !mounted) return;
    await _runAction(
      StorageAction.attachToPool(name: pool.name, existing: existing, new_: path),
      l10n.storageAttach,
      l10n.storageAttachBody(existing, path),
      confirmWord: path,
    );
  }

  Future<void> _showHealth(DiskHealth health) async {
    await context.showSheet<void>(
      title: l10n.storageDetails,
      child: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          children: [
            Text(health.device, style: UIs.text12Grey),
            Text(l10n.storageAttributes, style: UIs.text11Grey),
            for (final attribute in health.attributes)
              ListTile(
                dense: true,
                title: Text('${attribute.id ?? ''} ${attribute.name}'),
                subtitle: Text(
                  '${l10n.storageAttrValue}: ${attribute.value ?? '–'} · ${l10n.storageAttrWorst}: ${attribute.worst ?? '–'} · ${l10n.storageAttrThresh}: ${attribute.thresh ?? '–'}',
                ),
                trailing: Text(attribute.raw),
              ),
            if (health.attributes.isEmpty) ListTile(title: Text(l10n.storageNothingToShow)),
            Text(l10n.storageSelfTests, style: UIs.text11Grey),
            for (final test in health.tests) ListTile(dense: true, title: Text(_testText(test))),
            if (health.tests.isEmpty) ListTile(title: Text(l10n.storageNothingToShow)),
          ],
        ),
      ),
      actions: [
        Btn.text(
          text: l10n.storageLongTest,
          onTap: () {
            context.popSheet();
            unawaited(_runAction(
              StorageAction.smartTest(device: health.device, long: true),
              l10n.storageLongTest,
              l10n.storageSmartLongTestBody(health.device),
            ));
          },
        ),
        Btn.text(text: libL10n.ok, onTap: context.popSheet),
      ],
    );
  }
}

final class _CreateDraft {
  const _CreateDraft(this.name, this.layout, this.devices);
  final String name;
  final String layout;
  final List<String> devices;
}
