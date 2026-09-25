import 'dart:async';
import 'dart:math' show Random;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/widget/group_title.dart';

part 'edit_pane.dart';
part 'settings.dart';

/// A guest's hardware, and changing it — the design's sectioned edit pane:
/// groups under a title and a rule, each saying on the right what it amounts
/// to, or that a change waits for the next start. Wide, an index of the
/// groups runs down the left.
///
/// Every value shown is what the next start gets. What the running guest has
/// instead is shown by the field or device it changes, with a way to drop it
/// where the host keeps such a list (PVE); the guest view says so above its
/// tabs, with a restart and — on PVE — dropping them all.
///
/// Steppers and the boot order are drafts, saved or dropped with the buttons
/// under them: one click is one step, not one change to the host. A device's
/// own switches — its network, its link, a CD-ROM's media — are one change
/// each, made as they are pressed.
class VirtHardwareView extends ConsumerStatefulWidget {
  const VirtHardwareView({
    super.key,
    required this.serverId,
    required this.guest,
    required this.caps,
  });

  final String serverId;
  final VirtGuest guest;
  final VirtCapabilities caps;

  @override
  ConsumerState<VirtHardwareView> createState() => _VirtHardwareViewState();
}

class _CpuDraft {
  const _CpuDraft(this.sockets, this.cores, this.online);

  final int sockets;
  final int cores;

  /// Null for all of them.
  final int? online;
}

class _MemDraft {
  const _MemDraft(this.mib, this.minMib, this.swapMib);

  final int mib;
  final int? minMib;
  final int? swapMib;
}

class _VirtHardwareViewState extends ConsumerState<VirtHardwareView>
    with _EditPane<VirtHardwareView> {
  @override
  String get _serverId => widget.serverId;
  @override
  VirtGuest get _guest => widget.guest;
  @override
  VirtCapabilities get _caps => widget.caps;

  _CpuDraft? _cpu;
  _MemDraft? _mem;

  /// The boot order being edited: every bootable device, and which of them
  /// are booted from.
  List<String>? _boot;
  Set<String> _bootOn = const {};

  /// Grown sizes not saved yet, by disk.
  final _grow = <String, int>{};


  /// The add block that is open: `disk` or `nic`.
  String? _adding;
  List<VirtStoragePool>? _addPools;
  VirtStoragePool? _addPool;
  int _addGib = 32;
  final _mount = TextEditingController(text: '/mnt/data');
  List<VirtNetwork>? _nets;
  VirtNetwork? _addNet;

  Future<List<VirtVolume>>? _isos;

  /// The device add block's kind and choice, and the host's devices for it.
  VirtHwDeviceKind? _devKind;
  VirtHostDevice? _devPick;
  Future<VirtHostDevices>? _hostDevs;


  @override
  void initState() {
    super.initState();
    // Where a NIC can go: read once, for the NIC rows' network choice.
    final host = ref.read(virtHostProvider(widget.serverId)).kind;
    if (host != null) unawaited(_loadNets(host).catchError((Object _) {}));
  }

  @override
  void dispose() {
    _mount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildEditPane(_groups);

  /// The design's order. Groups task B adds (devices and passthrough,
  /// display, firmware) go where the design has them: between the CD-ROM
  /// and the boot order.
  List<_Group> _groups(VirtHardware hw, bool busy) => [
    _cpuGroup(hw, busy),
    _memGroup(hw, busy),
    _diskGroup(hw, busy),
    _nicGroup(hw, busy),
    if (!_lxc) _devicesGroup(hw, busy),
    if (hw.display case final d?) _displayGroup(hw, d, busy),
    // A container boots its root; it has no order to set.
    if (hw.boot != null || hw.firmware != null) _bootGroup(hw, busy),
    _configGroup(hw, busy),
  ];

  /// Whether a change to [keys] waits for the next start: the running guest
  /// has it pending.
  bool _waits(VirtHardware hw, Iterable<String> keys) =>
      hw.running && hw.pendingFor(keys);

  // --- CPU ---

  _Group _cpuGroup(VirtHardware hw, bool busy) {
    final saved = _CpuDraft(hw.cpu.sockets, hw.cpu.cores, hw.cpu.online);
    final d = _cpu ?? saved;
    final threads = hw.cpu.threads;
    final total = d.sockets * d.cores * threads;
    final maxCpus = hw.limits.hostCpus ?? 4096;
    void edit(_CpuDraft next) => setState(() => _cpu = next);
    final changed =
        _cpu != null &&
        (d.sockets != saved.sockets ||
            d.cores != saved.cores ||
            d.online != saved.online);
    final waits = _waits(hw, const ['cpu', 'cores', 'sockets', 'vcpus']);
    final allocated = _allocated((g) => g.vcpu);
    return _Group(
      key: 'cpu',
      title: _lxc ? 'CPU' : l10n.virtHwProcessor,
      right: waits
          ? l10n.virtHwLater
          : l10n.virtHwHostCpus(hw.limits.hostCpus ?? 0, allocated),
      warn: waits,
      indexNote: _lxc ? '${hw.cpu.cores}' : '${hw.cpu.total} vCPU',
      rows: [
        if (_lxc)
          _step(
            Icons.developer_board,
            l10n.virtHwCores,
            '${d.cores}',
            key: 'cores',
            onDec: d.cores <= 1
                ? null
                : () => edit(_CpuDraft(1, d.cores - 1, null)),
            onInc: d.cores >= maxCpus
                ? null
                : () => edit(_CpuDraft(1, d.cores + 1, null)),
          )
        else ...[
          _step(
            Icons.developer_board,
            'vCPU',
            '$total',
            key: 'cores',
            onDec: d.cores <= 1
                ? null
                : () => edit(
                    _CpuDraft(
                      d.sockets,
                      d.cores - 1,
                      _clampOnline(d.online, d.sockets * (d.cores - 1) * threads),
                    ),
                  ),
            onInc: total + d.sockets * threads > maxCpus
                ? null
                : () => edit(_CpuDraft(d.sockets, d.cores + 1, d.online)),
          ),
          _step(
            Icons.view_module_outlined,
            l10n.virtHwSockets,
            '${d.sockets}',
            key: 'sockets',
            onDec: d.sockets <= 1
                ? null
                : () => edit(
                    _CpuDraft(
                      d.sockets - 1,
                      d.cores,
                      _clampOnline(d.online, (d.sockets - 1) * d.cores * threads),
                    ),
                  ),
            onInc: total + d.cores * threads > maxCpus
                ? null
                : () => edit(_CpuDraft(d.sockets + 1, d.cores, d.online)),
          ),
          _step(
            Icons.bolt_outlined,
            l10n.virtHwOnline,
            d.online == null ? '$total' : '${d.online} / $total',
            key: 'online',
            onDec: (d.online ?? total) <= 1
                ? null
                : () => edit(
                    _CpuDraft(d.sockets, d.cores, (d.online ?? total) - 1),
                  ),
            onInc: d.online == null
                ? null
                : () => edit(
                    _CpuDraft(
                      d.sockets,
                      d.cores,
                      d.online! + 1 >= total ? null : d.online! + 1,
                    ),
                  ),
          ),
          if (hw.cpuTypes.isNotEmpty || hw.cpu.type != null)
            _field(
              Icons.memory_outlined,
              l10n.virtHwModel,
              hw.cpu.type ?? l10n.virtHwCpuTypeDefault,
              key: const ValueKey('hw:cputype'),
              onTap: busy || hw.cpuTypes.isEmpty
                  ? null
                  : () => _pickCpuType(hw),
              trailing: hw.cpuTypes.isEmpty
                  ? null
                  : const Icon(Icons.chevron_right, size: 17),
            ),
          _field(
            Icons.grid_view,
            l10n.virtHwTopology,
            l10n.virtHwTopologyValue(d.sockets, d.cores, threads),
          ),
        ],
        ..._pendingRows(
          hw,
          busy,
          (p) => _placeOf(hw, p.key) == _PendingPlace.cpu,
        ),
        if (changed)
          _actions([
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _cpu = null),
            ),
            _Action(
              libL10n.save,
              key: 'hw:cpu:save',
              primary: true,
              onTap: busy
                  ? null
                  : () => _save(
                      hw,
                      VirtHwSetCpu(
                        sockets: d.sockets,
                        cores: d.cores,
                        online: d.online,
                      ),
                      () => _cpu = null,
                    ),
            ),
          ]),
      ],
    );
  }

  static int? _clampOnline(int? online, int total) =>
      online == null || online >= total ? null : online;

  /// The sum of [of] over the host's guests: what is already given out.
  int _allocated(int? Function(VirtGuest g) of) {
    final guests =
        ref.read(virtHostProvider(widget.serverId)).data?.guests ??
        const <VirtGuest>[];
    return guests.fold(0, (sum, g) => sum + (of(g) ?? 0));
  }

  // --- Memory ---

  static String _mib(int mib) {
    if (mib < 1024) return '$mib MiB';
    final gib = mib / 1024;
    return '${gib.toStringAsFixed(mib % 1024 == 0 ? 0 : 1)} GiB';
  }

  /// A step of memory: a quarter of a GiB up to one, whole GiB above.
  static int _memStep(int mib, {required bool up}) =>
      mib < 1024 || (!up && mib == 1024) ? 256 : 1024;

  _Group _memGroup(VirtHardware hw, bool busy) {
    final saved = _MemDraft(
      hw.memory.mib,
      hw.memory.minMib,
      hw.memory.swapMib,
    );
    final d = _mem ?? saved;
    void edit(_MemDraft next) => setState(() => _mem = next);
    final changed =
        _mem != null &&
        (d.mib != saved.mib ||
            d.minMib != saved.minMib ||
            d.swapMib != saved.swapMib);
    final hostMib = switch (hw.limits.hostMemoryBytes) {
      final b? => b >> 20,
      null => null,
    };
    final waits = _waits(hw, const ['memory', 'balloon', 'swap']);
    final allocated = _allocated((g) => g.memBytes) >> 20;
    final used = ref.watch(
      virtHostProvider(
        widget.serverId,
      ).select((s) => s.statsOf(widget.guest.id)?.memUsed),
    );
    final pve = _pve;
    final current = d.minMib ?? d.mib;
    return _Group(
      key: 'mem',
      title: libL10n.memory,
      right: waits
          ? l10n.virtHwLater
          : hostMib == null
          ? ''
          : l10n.virtHwHostMem(_mib(hostMib), _mib(allocated)),
      warn: waits,
      indexNote: [
        _mib(hw.memory.mib),
        if (hw.memory.balloon && hw.memory.minMib != 0) 'balloon',
      ].join(' · '),
      rows: [
        _step(
          Icons.memory,
          libL10n.memory,
          _mib(d.mib),
          key: 'memory',
          onDec: d.mib - _memStep(d.mib, up: false) < virtHwMinMemoryMib
              ? null
              : () {
                  final mib = d.mib - _memStep(d.mib, up: false);
                  final min = d.minMib;
                  edit(
                    _MemDraft(
                      mib,
                      min != null && min > mib ? mib : min,
                      d.swapMib,
                    ),
                  );
                },
          onInc:
              hostMib != null && d.mib + _memStep(d.mib, up: true) > hostMib
              ? null
              : () => edit(
                  _MemDraft(
                    d.mib + _memStep(d.mib, up: true),
                    d.minMib,
                    d.swapMib,
                  ),
                ),
        ),
        if (hw.memory.balloon && pve)
          _toggle(
            Icons.compress,
            'virtio-balloon',
            d.minMib != 0,
            key: 'balloon',
            note: l10n.virtHwBalloonNote,
            onChanged: (on) => edit(
              _MemDraft(
                d.mib,
                on ? (hw.memory.minMib == 0 ? null : hw.memory.minMib) : 0,
                d.swapMib,
              ),
            ),
          ),
        // libvirt's balloon is a target the host sets rather than a floor: a
        // stepper for it rather than a switch.
        if (hw.memory.balloon && !pve)
          _step(
            Icons.compress,
            l10n.virtHwBalloonLibvirt,
            _mib(current),
            key: 'balloon',
            onDec: current <= 256
                ? null
                : () => edit(_MemDraft(d.mib, current - 256, d.swapMib)),
            onInc: current >= d.mib
                ? null
                : () {
                    final next = current + 256;
                    edit(
                      _MemDraft(d.mib, next >= d.mib ? null : next, d.swapMib),
                    );
                  },
          ),
        if (_lxc && d.swapMib != null)
          _step(
            Icons.swap_horiz,
            l10n.virtHwSwap,
            _mib(d.swapMib!),
            key: 'swap',
            onDec: d.swapMib! <= 0
                ? null
                : () => edit(
                    _MemDraft(
                      d.mib,
                      d.minMib,
                      (d.swapMib! - 512).clamp(0, 1 << 30),
                    ),
                  ),
            onInc: () => edit(_MemDraft(d.mib, d.minMib, d.swapMib! + 512)),
          ),
        if (hw.running && used != null)
          _field(Icons.data_usage, l10n.virtHwGuestUsed, used.bytes2Str),
        ..._pendingRows(
          hw,
          busy,
          (p) => _placeOf(hw, p.key) == _PendingPlace.memory,
        ),
        if (changed)
          _actions([
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _mem = null),
            ),
            _Action(
              libL10n.save,
              key: 'hw:memory:save',
              primary: true,
              onTap: busy
                  ? null
                  : () => _save(
                      hw,
                      VirtHwSetMemory(
                        mib: d.mib,
                        minMib: d.minMib,
                        swapMib: d.swapMib,
                      ),
                      () => _mem = null,
                    ),
            ),
          ]),
      ],
    );
  }

  // --- Disks ---

  _Group _diskGroup(VirtHardware hw, bool busy) {
    final disks = [
      for (final d in hw.disks)
        if (d.kind != VirtHwDiskKind.cdrom) d,
    ];
    final total = disks.fold(0, (s, d) => s + (d.size ?? 0));
    return _Group(
      key: 'disks',
      title: _lxc ? l10n.virtHwDisksLxc : libL10n.disk,
      right: l10n.virtHwTotal(total.bytes2Str),
      warn: _waits(hw, disks.map((d) => d.key)),
      indexNote: disks.isEmpty ? '—' : disks.map((d) => d.key).join(', '),
      rows: [
        for (final d in disks) ..._diskRows(hw, d, busy),
        // Pending for a disk the next start no longer has: removed.
        ..._pendingRows(
          hw,
          busy,
          (p) =>
              _placeOf(hw, p.key) == _PendingPlace.disk && hw.disk(p.key) == null,
        ),
        if (_adding == 'disk')
          ..._addDiskRows(hw, busy)
        else
          _empty(
            _lxc ? l10n.virtHwMountFromPool : l10n.virtHwDiskHotplug,
            _lxc ? l10n.virtHwAddMount : l10n.virtHwAddDisk,
            key: 'hw:disk:add',
            onTap: busy ? null : () => _openAdd('disk'),
          ),
      ],
    );
  }

  List<Widget> _diskRows(VirtHardware hw, VirtHwDisk d, bool busy) {
    final size = d.size;
    final grown = _grow[d.key];
    final summary = [
      ?size?.bytes2Str,
      if (_lxc) ?d.mountPoint else ...[?d.format, ?d.bus],
    ].join(' · ');
    return [
      _disc(d.key, Icons.storage, d.key, summary),
      ..._pendingRows(hw, busy, (p) => p.key == d.key, indent: true),
      if (_open.contains(d.key)) ...[
        _field(
          Icons.folder_outlined,
          l10n.virtHwSource,
          d.source ?? '—',
          mono: true,
          indent: true,
        ),
        if (size != null)
          _step(
            Icons.straighten,
            libL10n.capacity,
            (grown ?? size).bytes2Str,
            key: 'grow:${d.key}',
            indent: true,
            onDec: grown == null || grown - (8 << 30) <= size
                ? (grown == null
                      ? null
                      : () => setState(() => _grow.remove(d.key)))
                : () => setState(() => _grow[d.key] = grown - (8 << 30)),
            onInc: () =>
                setState(() => _grow[d.key] = (grown ?? size) + (8 << 30)),
          ),
        if (!_lxc && d.kind == VirtHwDiskKind.disk) ...[
          if (hw.support.buses.isNotEmpty)
            _seg(
              Icons.cable,
              l10n.virtHwBus,
              hw.support.buses,
              d.bus,
              key: 'disk:${d.key}:bus',
              indent: true,
              // A disk moves to another bus only while nothing has it open.
              onSelected: busy || hw.running
                  ? null
                  : (bus) => _apply(hw, VirtHwUpdateDisk(key: d.key, bus: bus)),
            ),
          if (hw.running && hw.support.buses.isNotEmpty)
            _text(l10n.virtHwBusStopped, indent: true),
          if (hw.support.caches.isNotEmpty)
            _seg(
              Icons.cached,
              l10n.virtHwCache,
              [
                for (final c in hw.support.caches)
                  c == 'default' ? l10n.virtHwCpuTypeDefault : c,
              ],
              d.cache ?? l10n.virtHwCpuTypeDefault,
              key: 'disk:${d.key}:cache',
              indent: true,
              onSelected: busy
                  ? null
                  : (c) => _apply(
                      hw,
                      VirtHwUpdateDisk(
                        key: d.key,
                        cache: c == l10n.virtHwCpuTypeDefault ? 'default' : c,
                      ),
                    ),
            ),
        ],
        _text(
          hw.running ? l10n.virtHwGrowNoteRunning : l10n.virtHwGrowNote,
          indent: true,
        ),
        _actions(indent: true, [
          if (grown != null) ...[
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _grow.remove(d.key)),
            ),
            _Action(
              l10n.virtHwGrow,
              key: 'hw:disk:${d.key}:grow',
              primary: true,
              onTap: busy
                  ? null
                  : () => _save(
                      hw,
                      VirtHwGrowDisk(key: d.key, bytes: grown),
                      () => _grow.remove(d.key),
                    ),
            ),
          ],
          // A container's root is its own.
          if (d.kind != VirtHwDiskKind.rootfs)
            _Action(
              l10n.virtHwDetach,
              key: 'hw:disk:${d.key}:detach',
              icon: Icons.link_off,
              danger: true,
              onTap: busy ? null : () => _removeDisk(hw, d),
            ),
        ]),
      ],
    ];
  }

  List<Widget> _addDiskRows(VirtHardware hw, bool busy) {
    final pools = _addPools;
    final pool = _addPool;
    final add = pool == null
        ? null
        : VirtHwAddDisk(
            storage: pool,
            gib: _addGib,
            mountPoint: _lxc ? _mount.text.trim() : null,
          );
    final issue = add == null ? null : _issueText(hw, virtHwIssue(hw, add));
    return [
      _disc(
        '__add',
        Icons.add_circle_outline,
        _lxc ? l10n.virtHwNewMount : l10n.virtHwNewDisk,
        l10n.virtHwPickPool,
        onTap: () => setState(() => _adding = null),
      ),
      if (pools == null)
        const Padding(
          padding: EdgeInsets.all(7),
          child: Center(child: SizedLoading.small),
        )
      else if (pools.isEmpty)
        _text(l10n.virtHwNoStorage, indent: true)
      else ...[
        _choice([
          for (final p in pools)
            _Choice(
              key: 'hw:disk:pool:${p.id}',
              icon: Icons.dns_outlined,
              label: p.name,
              sub: [
                p.type,
                if (p.available case final a?) l10n.virtHwFree(a.bytes2Str),
              ].join(' · '),
              selected: p.id == pool?.id,
              onTap: () => setState(() => _addPool = p),
            ),
        ], indent: true),
        _step(
          Icons.straighten,
          libL10n.capacity,
          '$_addGib GiB',
          key: 'add:size',
          indent: true,
          onDec: _addGib <= 8 ? null : () => setState(() => _addGib -= 8),
          onInc: () => setState(() => _addGib += 8),
        ),
        if (_lxc)
          Padding(
            padding: const EdgeInsets.only(left: _indent),
            child: Input(
              key: const ValueKey('hw:disk:mount'),
              controller: _mount,
              label: l10n.virtHwMountPoint,
              icon: Icons.folder_open,
              noWrap: true,
              suggestion: false,
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (hw.running) _text(l10n.virtHwHotplugNow, indent: true),
        if (issue != null) _text(issue, indent: true, error: true),
      ],
      _actions(indent: true, [
        _Action(
          libL10n.cancel,
          icon: Icons.close,
          onTap: () => setState(() => _adding = null),
        ),
        _Action(
          libL10n.add,
          key: 'hw:disk:add:ok',
          primary: true,
          onTap: busy || add == null || issue != null
              ? null
              : () => _save(hw, add, () => _adding = null),
        ),
      ]),
    ];
  }

  // --- Network ---

  _Group _nicGroup(VirtHardware hw, bool busy) {
    return _Group(
      key: 'nics',
      title: l10n.virtHwNics,
      right: '${hw.nics.length}',
      warn: _waits(hw, hw.nics.map((n) => n.key)),
      indexNote: hw.nics.isEmpty
          ? '—'
          : hw.nics.map((n) => n.source ?? n.key).join(', '),
      rows: [
        for (final (i, n) in hw.nics.indexed) ..._nicRows(hw, n, i, busy),
        ..._pendingRows(
          hw,
          busy,
          (p) =>
              _placeOf(hw, p.key) == _PendingPlace.nic && hw.nic(p.key) == null,
        ),
        if (_adding == 'nic')
          ..._addNicRows(hw, busy)
        else
          _empty(
            l10n.virtHwNicHotplug,
            l10n.virtHwAddNic,
            key: 'hw:nic:add',
            onTap: busy ? null : () => _openAdd('nic'),
          ),
      ],
    );
  }

  /// What a NIC is called: PVE's option, a container's interface, or
  /// libvirt's order among them.
  String _nicName(VirtHwNic n, int i) =>
      n.name ?? (n.key.startsWith('net') ? n.key : 'nic$i');

  List<Widget> _nicRows(VirtHardware hw, VirtHwNic n, int i, bool busy) {
    final editable =
        n.type == null || n.type == 'network' || n.type == 'bridge';
    final nets = _nets;
    return [
      _disc(
        n.key,
        Icons.lan_outlined,
        _nicName(n, i),
        [?n.model, ?n.source, if (!n.linkUp) l10n.virtHwLinkDown].join(' · '),
      ),
      ..._pendingRows(hw, busy, (p) => p.key == n.key, indent: true),
      if (_open.contains(n.key)) ...[
        if (editable && nets != null && nets.isNotEmpty)
          _seg(
            Icons.hub_outlined,
            libL10n.network,
            [for (final x in nets) x.name],
            n.source,
            key: 'nic:${n.key}:net',
            indent: true,
            onSelected: busy
                ? null
                : (name) => _apply(
                    hw,
                    VirtHwUpdateNic(
                      key: n.key,
                      network: nets.firstWhere((x) => x.name == name),
                      linkUp: n.linkUp,
                    ),
                  ),
          )
        else
          _field(
            Icons.hub_outlined,
            libL10n.network,
            n.source ?? '—',
            indent: true,
          ),
        if (!_lxc && hw.support.nicModels.isNotEmpty && editable)
          _seg(
            Icons.memory_outlined,
            l10n.virtHwModel,
            [
              ...hw.support.nicModels,
              // One this app does not offer stays shown as what it is.
              if (n.model case final m? when !hw.support.nicModels.contains(m)) m,
            ],
            n.model,
            key: 'nic:${n.key}:model',
            indent: true,
            onSelected: busy
                ? null
                : (m) => _apply(hw, VirtHwSetNicHardware(key: n.key, model: m)),
          ),
        if (n.mac case final mac?)
          _field(
            Icons.fingerprint,
            l10n.virtHwMac,
            mac,
            key: ValueKey('nic:${n.key}:mac'),
            mono: true,
            indent: true,
            onTap: busy || !hw.support.mac || !editable
                ? null
                : () => _editMac(hw, n),
          ),
        if (editable)
          _toggle(
            Icons.link,
            l10n.virtHwLinkUp,
            n.linkUp,
            key: 'nic:${n.key}:link',
            note: l10n.virtHwLinkNote,
            indent: true,
            onChanged: busy
                ? null
                : (up) => _apply(hw, VirtHwUpdateNic(key: n.key, linkUp: up)),
          ),
        if (n.firewall case final fw?)
          _toggle(
            Icons.local_fire_department_outlined,
            l10n.virtHwFirewall,
            fw,
            key: 'nic:${n.key}:firewall',
            indent: true,
            onChanged: busy
                ? null
                : (on) => _apply(
                    hw,
                    VirtHwUpdateNic(key: n.key, linkUp: n.linkUp, firewall: on),
                  ),
          ),
        _actions(indent: true, [
          _Action(
            l10n.virtHwRemove,
            key: 'hw:nic:${n.key}:remove',
            icon: Icons.delete_outline,
            danger: true,
            onTap: busy ? null : () => _removeNic(hw, n, _nicName(n, i)),
          ),
        ]),
      ],
    ];
  }

  List<Widget> _addNicRows(VirtHardware hw, bool busy) {
    final nets = _nets;
    final net = _addNet;
    return [
      _disc(
        '__add',
        Icons.add_circle_outline,
        l10n.virtHwNewNic,
        l10n.virtHwPickNet,
        onTap: () => setState(() => _adding = null),
      ),
      if (nets == null)
        const Padding(
          padding: EdgeInsets.all(7),
          child: Center(child: SizedLoading.small),
        )
      else if (nets.isEmpty)
        _text(l10n.virtHwNoNetworks, indent: true)
      else
        _seg(
          Icons.lan_outlined,
          libL10n.network,
          [for (final x in nets) x.name],
          net?.name,
          key: 'add:net',
          indent: true,
          onSelected: (name) =>
              setState(() => _addNet = nets.firstWhere((x) => x.name == name)),
        ),
      if (hw.running) _text(l10n.virtHwHotplugNow, indent: true),
      _actions(indent: true, [
        _Action(
          libL10n.cancel,
          icon: Icons.close,
          onTap: () => setState(() => _adding = null),
        ),
        _Action(
          libL10n.add,
          key: 'hw:nic:add:ok',
          primary: true,
          onTap: busy || net == null
              ? null
              : () =>
                    _save(hw, VirtHwAddNic(network: net), () => _adding = null),
        ),
      ]),
    ];
  }

  // --- CD-ROM ---

  /// CD-ROMs, host USB and PCI devices, and the TPM: the design's
  /// "CD-ROM and passthrough".
  _Group _devicesGroup(VirtHardware hw, bool busy) {
    final drives = [
      for (final d in hw.disks)
        if (d.kind == VirtHwDiskKind.cdrom) d,
    ];
    final kinds = [
      if (hw.support.usb) VirtHwDeviceKind.usb,
      if (hw.support.pci) VirtHwDeviceKind.pci,
      if (hw.support.tpm && !hw.hasTpm) VirtHwDeviceKind.tpm,
    ];
    return _Group(
      key: 'devices',
      title: l10n.virtHwDevices,
      right: '${drives.length + hw.devices.length}',
      warn: _waits(hw, [
        ...drives.map((d) => d.key),
        ...hw.devices.map((d) => d.key),
      ]),
      indexNote: [
        for (final _ in drives) l10n.virtHwCdrom,
        for (final d in hw.devices) _deviceName(d.kind),
      ].join(', ').ifEmpty('—'),
      rows: [
        for (final d in drives) ...[
          _disc(
            d.key,
            Icons.album_outlined,
            '${d.key} · ${l10n.virtHwCdrom}',
            d.source == null ? l10n.virtHwNoMedia : _baseName(d.source!),
            onTap: () {
              setState(
                () => _open.contains(d.key)
                    ? _open.remove(d.key)
                    : _open.add(d.key),
              );
              _isos ??= _loadIsos();
            },
          ),
          ..._pendingRows(hw, busy, (p) => p.key == d.key, indent: true),
          if (_open.contains(d.key)) ...[
            FutureBuilder<List<VirtVolume>>(
              future: _isos,
              builder: (_, snap) {
                final isos = snap.data;
                if (isos == null) {
                  return const Padding(
                    padding: EdgeInsets.all(7),
                    child: Center(child: SizedLoading.small),
                  );
                }
                bool inDrive(VirtVolume v) =>
                    v.id == d.source || v.path == d.source;
                return _choice([
                  _Choice(
                    key: 'hw:media:none',
                    icon: Icons.block,
                    label: l10n.virtHwEmpty,
                    selected: d.source == null,
                    onTap: busy || d.source == null
                        ? null
                        : () => _apply(hw, VirtHwSetMedia(key: d.key)),
                  ),
                  for (final v in isos)
                    _Choice(
                      key: 'hw:media:${v.id}',
                      icon: Icons.album_outlined,
                      label: v.name,
                      sub: v.capacity?.bytes2Str,
                      selected: inDrive(v),
                      onTap: busy || inDrive(v)
                          ? null
                          : () => _apply(
                              hw,
                              VirtHwSetMedia(key: d.key, media: v),
                            ),
                    ),
                ], indent: true);
              },
            ),
            _actions(indent: true, [
              if (d.source != null)
                _Action(
                  l10n.virtHwEject,
                  key: 'hw:media:${d.key}:eject',
                  icon: Icons.eject,
                  onTap: busy
                      ? null
                      : () => _apply(hw, VirtHwSetMedia(key: d.key)),
                ),
              _Action(
                l10n.virtHwRemoveCdrom,
                key: 'hw:media:${d.key}:remove',
                icon: Icons.delete_outline,
                danger: true,
                onTap: busy ? null : () => _removeDisk(hw, d),
              ),
            ]),
          ],
        ],
        for (final d in hw.devices) ..._deviceRows(hw, d, busy),
        if (_adding == 'dev')
          ..._addDeviceRows(hw, kinds, busy)
        else if (kinds.isNotEmpty)
          _empty(
            l10n.virtHwDevicesEmpty,
            l10n.virtHwAddDevice,
            key: 'hw:add:dev',
            onTap: busy ? null : () => _openAddDevice(kinds.first),
          ),
      ],
    );
  }

  String _deviceName(VirtHwDeviceKind kind) => switch (kind) {
    VirtHwDeviceKind.usb => 'USB',
    VirtHwDeviceKind.pci => l10n.virtHwPci,
    VirtHwDeviceKind.tpm => 'TPM',
  };

  IconData _deviceIcon(VirtHwDeviceKind kind) => switch (kind) {
    VirtHwDeviceKind.usb => Icons.usb,
    VirtHwDeviceKind.pci => Icons.developer_board,
    VirtHwDeviceKind.tpm => Icons.shield_outlined,
  };

  List<Widget> _deviceRows(VirtHardware hw, VirtHwDevice d, bool busy) => [
    _disc(d.key, _deviceIcon(d.kind), _deviceName(d.kind), d.detail ?? d.key),
    ..._pendingRows(hw, busy, (p) => p.key == d.key, indent: true),
    if (_open.contains(d.key)) ...[
      _field(
        Icons.tag,
        d.kind == VirtHwDeviceKind.pci ? libL10n.addr : libL10n.device,
        [d.detail ?? d.key, if (d.mapping) '(mapping)'].join(' '),
        mono: true,
        indent: true,
      ),
      switch (d.kind) {
        VirtHwDeviceKind.usb => _text(l10n.virtHwUsbHotplug, indent: true),
        VirtHwDeviceKind.pci => _callout(
          l10n.virtHwPciTitle,
          l10n.virtHwPciBody,
          warn: false,
          indent: true,
        ),
        VirtHwDeviceKind.tpm => _text(l10n.virtHwTpmNote, indent: true),
      },
      _actions(indent: true, [
        _Action(
          l10n.virtHwRemove,
          key: 'hw:dev:${d.key}:remove',
          icon: Icons.delete_outline,
          danger: true,
          onTap: busy ? null : () => _removeDevice(hw, d),
        ),
      ]),
    ],
  ];

  /// The add block: the kind, then the device (USB, PCI) or the storage for
  /// the TPM's state (PVE).
  List<Widget> _addDeviceRows(
    VirtHardware hw,
    List<VirtHwDeviceKind> kinds,
    bool busy,
  ) {
    final kind = _devKind ?? kinds.firstOrNull;
    final pick = _devPick;
    final change = kind == null
        ? null
        : VirtHwAddDevice(kind: kind, host: pick, storage: _addPool?.name);
    final issue = change == null ? null : virtHwIssue(hw, change, host: _host);
    return [
      _disc('__add_dev', Icons.add_circle_outline, l10n.virtHwNewDevice,
          kinds.map(_deviceName).join(' · ')),
      if (kinds.length > 1)
        _seg(
          Icons.category_outlined,
          libL10n.type,
          [for (final k in kinds) _deviceName(k)],
          kind == null ? null : _deviceName(kind),
          key: 'dev:add:kind',
          indent: true,
          onSelected: (name) => setState(() {
            _devKind = kinds.firstWhere((k) => _deviceName(k) == name);
            _devPick = null;
          }),
        ),
      if (kind == VirtHwDeviceKind.tpm && _pve) ..._storageChoice(),
      if (kind == VirtHwDeviceKind.tpm) _text(l10n.virtHwTpmNote, indent: true),
      if (kind == VirtHwDeviceKind.usb || kind == VirtHwDeviceKind.pci)
        FutureBuilder<VirtHostDevices>(
          future: _hostDevs,
          builder: (_, snap) {
            if (snap.error case final e?) {
              return _text(e is VirtErr ? e.title : '$e', indent: true, error: true);
            }
            final devs = snap.data;
            if (devs == null) {
              return const Padding(
                padding: EdgeInsets.all(7),
                child: Center(child: SizedLoading.small),
              );
            }
            final list = kind == VirtHwDeviceKind.usb ? devs.usb : devs.pci;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kind == VirtHwDeviceKind.pci)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: devs.iommu
                        ? _callout(l10n.virtHwPciTitle, l10n.virtHwPciBody, indent: true)
                        : _callout(
                            l10n.virtHwIommuOffTitle,
                            l10n.virtHwIommuOffBody,
                            indent: true,
                            key: const ValueKey('hw:dev:iommu-off'),
                          ),
                  ),
                if (devs.mappingsOnly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _text(l10n.virtHwMappingsOnly, indent: true),
                  ),
                if (list.isEmpty)
                  _text(l10n.virtHwNoHostDevices, indent: true)
                else
                  _choice([
                    for (final x in list)
                      _Choice(
                        key: 'hw:dev:pick:${x.id}',
                        icon: x.mapping ? Icons.link : _deviceIcon(kind!),
                        label: x.label,
                        sub: [
                          x.detail,
                          if (x.iommuGroup case final g?) l10n.virtHwIommuGroup(g),
                          if (x.groupSize > 1) l10n.virtHwIommuShared(x.groupSize),
                        ].nonNulls.join(' · '),
                        selected: pick?.id == x.id && pick?.mapping == x.mapping,
                        onTap: () => setState(() => _devPick = x),
                      ),
                  ], indent: true),
              ],
            );
          },
        ),
      if (_issueText(hw, issue) case final t? when pick != null || kind == VirtHwDeviceKind.tpm)
        _text(t, indent: true, error: true),
      _actions(indent: true, [
        _Action(
          libL10n.cancel,
          icon: Icons.close,
          onTap: () => setState(() => _adding = null),
        ),
        _Action(
          libL10n.add,
          key: 'hw:dev:add',
          primary: true,
          onTap: busy || change == null || issue != null
              ? null
              : () => _save(hw, change, () {
                  _adding = null;
                  _devPick = null;
                }),
        ),
      ]),
    ];
  }

  /// The storages a disk-like volume (TPM state, EFI variables) can go on.
  List<Widget> _storageChoice() {
    final pools = _addPools;
    if (pools == null) {
      return const [
        Padding(padding: EdgeInsets.all(7), child: Center(child: SizedLoading.small)),
      ];
    }
    if (pools.isEmpty) return [_text(l10n.virtHwNoStorage, indent: true)];
    return [
      _choice([
        for (final p in pools)
          _Choice(
            key: 'hw:pool:${p.id}',
            icon: Icons.dns_outlined,
            label: p.name,
            sub: p.type,
            selected: _addPool?.id == p.id,
            onTap: () => setState(() => _addPool = p),
          ),
      ], indent: true),
    ];
  }

  // --- Display ---

  static const _listenLocal = '127.0.0.1';
  static const _listenAll = '0.0.0.0';

  _Group _displayGroup(VirtHardware hw, VirtHwDisplay d, bool busy) {
    final support = hw.support;
    final waits = _waits(hw, const ['display', 'vga']);
    final listen = d.listen ?? _listenLocal;
    return _Group(
      key: 'display',
      title: l10n.virtHwDisplay,
      right: waits ? l10n.virtHwLater : '',
      warn: waits,
      indexNote: [?d.protocol?.toUpperCase(), ?d.gpu].join(' · ').ifEmpty('—'),
      rows: [
        if (support.protocols.length > 1)
          _seg(
            Icons.cast,
            l10n.virtHwProtocol,
            [for (final p in support.protocols) p.toUpperCase()],
            d.protocol?.toUpperCase(),
            key: 'display:protocol',
            onSelected: busy
                ? null
                : (p) => _apply(hw, VirtHwSetDisplay(protocol: p.toLowerCase())),
          )
        else if (d.protocol case final p?)
          _field(Icons.cast, l10n.virtHwProtocol, p.toUpperCase()),
        if (support.listen)
          _seg(
            Icons.wifi_tethering,
            l10n.virtHwListen,
            [
              _listenLocal,
              _listenAll,
              if (listen != _listenLocal && listen != _listenAll) listen,
            ],
            listen,
            key: 'display:listen',
            onSelected: busy
                ? null
                : (l) => _apply(hw, VirtHwSetDisplay(listen: l)),
          ),
        if (support.gpus.isNotEmpty)
          _seg(
            Icons.monitor,
            l10n.virtHwGpu,
            [
              ...support.gpus,
              if (d.gpu case final g? when !support.gpus.contains(g)) g,
            ],
            d.gpu,
            key: 'display:gpu',
            onSelected: busy ? null : (g) => _apply(hw, VirtHwSetDisplay(gpu: g)),
          ),
        if (d.port case final port?)
          _field(Icons.pin_outlined, libL10n.port, '$port', mono: true),
        if (support.listen && listen == _listenAll)
          _callout(
            l10n.virtHwListenAllTitle,
            l10n.virtHwListenAllBody,
            key: const ValueKey('hw:display:exposed'),
          ),
        ..._pendingRows(hw, busy, (p) => p.key == 'display' || p.key == 'vga'),
      ],
    );
  }

  static String _baseName(String source) {
    final slash = source.lastIndexOf('/');
    return slash < 0 ? source : source.substring(slash + 1);
  }

  // --- Boot and start ---

  /// The boot order, arrows and a numbered place as the design draws it.
  /// Starting with the host is the Settings view's.
  _Group _bootGroup(VirtHardware hw, bool busy) {
    final saved = hw.boot;
    final waits = _waits(hw, const ['boot', 'firmware', 'bios', 'efidisk0']);
    final rows = <Widget>[];
    if (hw.firmware case final fw? when hw.support.uefi || fw.uefi) {
      // Switching the firmware only while nothing runs on it.
      final canSwitch = !busy && !hw.running;
      rows.addAll([
        _choice([
          _Choice(
            key: 'hw:fw:uefi',
            icon: Icons.shield_outlined,
            label: 'UEFI',
            sub: l10n.virtHwUefiSub,
            selected: fw.uefi,
            onTap: fw.uefi || !canSwitch || !hw.support.uefi
                ? null
                : () => _setFirmware(hw, uefi: true, secureBoot: false),
          ),
          _Choice(
            key: 'hw:fw:bios',
            icon: Icons.memory_outlined,
            label: 'BIOS',
            sub: l10n.virtHwBiosSub,
            selected: !fw.uefi,
            onTap: !fw.uefi || !canSwitch
                ? null
                : () => _setFirmware(hw, uefi: false, secureBoot: false),
          ),
        ]),
        if (fw.uefi && hw.support.secureBoot)
          _toggle(
            Icons.verified_user_outlined,
            'Secure Boot',
            fw.secureBoot,
            key: 'hw:fw:secure',
            // Both backends make the variables again: PVE a new EFI disk,
            // libvirt the file from the Secure Boot template.
            note: '${l10n.virtHwSecureBootNote}\n${l10n.virtHwSecureBootVars}',
            onChanged: canSwitch
                ? (on) => _setFirmware(hw, uefi: true, secureBoot: on)
                : null,
          ),
        if (hw.running) _text(l10n.virtHwFirmwareStopped),
        ..._pendingRows(
          hw,
          busy,
          (p) => const {'firmware', 'bios', 'efidisk0'}.contains(p.key),
        ),
      ]);
    }
    if (saved != null) {
      final order = _boot ?? _bootDevices(hw);
      final on = _boot == null ? {...saved} : _bootOn;
      final picked = [
        for (final k in order)
          if (on.contains(k)) k,
      ];
      final changed = _boot != null && picked.join(',') != saved.join(',');
      void move(int i, int dir) {
        final list = [...order];
        final j = i + dir;
        final moved = list[i];
        list[i] = list[j];
        list[j] = moved;
        setState(() {
          _boot = list;
          _bootOn = on;
        });
      }

      rows.addAll([
        _text(l10n.virtHwBootOrder),
        for (final (i, k) in order.indexed)
          _reorder(
            key: 'boot:$k',
            ord: on.contains(k) ? '${picked.indexOf(k) + 1}' : '–',
            first: picked.isNotEmpty && picked.first == k,
            device: _bootDevice(hw, k),
            onToggle: () => setState(() {
              _boot = order;
              _bootOn = on.contains(k) ? ({...on}..remove(k)) : {...on, k};
            }),
            onUp: i == 0 ? null : () => move(i, -1),
            onDown: i == order.length - 1 ? null : () => move(i, 1),
          ),
        _text(l10n.virtHwBootTip),
        ..._pendingRows(
          hw,
          busy,
          (p) => _placeOf(hw, p.key) == _PendingPlace.boot,
        ),
        if (changed)
          _actions([
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _boot = null),
            ),
            _Action(
              libL10n.save,
              key: 'hw:boot:save',
              primary: true,
              onTap: busy || picked.isEmpty
                  ? null
                  : () => _save(hw, VirtHwSetBoot(picked), () => _boot = null),
            ),
          ]),
      ]);
    }
    if (hw.firmware != null) {
      rows.add(
        _callout(l10n.virtHwFirmwareWarnTitle, l10n.virtHwFirmwareWarnBody),
      );
    }
    return _Group(
      key: 'boot',
      title: l10n.virtHwBoot,
      right: waits ? l10n.virtHwLater : '',
      warn: waits,
      indexNote: [
        if (hw.firmware case final fw?) fw.uefi ? 'UEFI' : 'BIOS',
        if (saved != null && saved.isNotEmpty) saved.first,
      ].join(' · ').ifEmpty('—'),
      rows: rows,
    );
  }

  /// Every device a guest can boot from: the order's own first, the rest
  /// after it, off.
  List<String> _bootDevices(VirtHardware hw) {
    final boot = hw.boot ?? const [];
    return [
      ...boot,
      for (final d in hw.disks)
        if (d.kind == VirtHwDiskKind.disk || d.kind == VirtHwDiskKind.cdrom)
          if (!boot.contains(d.key)) d.key,
      for (final n in hw.nics)
        if (!boot.contains(n.key)) n.key,
    ];
  }

  (IconData, String, String) _bootDevice(VirtHardware hw, String key) {
    if (hw.disk(key) case final d?) {
      return d.kind == VirtHwDiskKind.cdrom
          ? (
              Icons.album_outlined,
              '$key · ${l10n.virtHwCdrom}',
              d.source == null ? l10n.virtHwNoMedia : _baseName(d.source!),
            )
          : (Icons.storage, '$key · ${libL10n.disk}', d.size?.bytes2Str ?? '');
    }
    if (hw.nic(key) case final n?) {
      return (
        Icons.lan_outlined,
        '${n.name ?? key} · ${libL10n.network}',
        n.source ?? '',
      );
    }
    return (Icons.help_outline, key, '');
  }

  // --- Configuration file ---

  _Group _configGroup(VirtHardware hw, bool busy) {
    final g = widget.guest;
    final (name, path) = switch ((_pve, _lxc)) {
      (true, true) => ('pct config ${g.vmid}', '/etc/pve/lxc/${g.vmid}.conf'),
      (true, false) => (
        'qm config ${g.vmid}',
        '/etc/pve/qemu-server/${g.vmid}.conf',
      ),
      _ => ('virsh dumpxml ${g.name}', '/etc/libvirt/qemu/${g.name}.xml'),
    };
    final open = _open.contains('config');
    return _Group(
      key: 'config',
      title: l10n.virtHwConfigFile,
      right: '',
      warn: false,
      indexNote: _pve ? (_lxc ? 'pct config' : 'qm config') : 'dumpxml',
      rows: [
        // Options this view does not edit, still waiting for the restart
        // the notice offers: listed rather than left unexplained.
        ..._pendingRows(
          hw,
          busy,
          (p) => _placeOf(hw, p.key) == _PendingPlace.other,
        ),
        _disc('config', Icons.code, name, open ? '' : path),
        if (open)
          Container(
            key: const ValueKey('hw:config:text'),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(13),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                hw.configText ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

// --- Actions ---

extension _Actions on _VirtHardwareViewState {
  /// Opens the add block for `disk` or `nic`, with what it offers read now.
  Future<void> _openAdd(String kind) async {
    // ignore: invalid_use_of_protected_member
    setState(() {
      _adding = kind;
      _addPools = null;
      _addPool = null;
      _addGib = 32;
      _addNet = _nets?.firstOrNull;
    });
    final host = ref.read(virtHostProvider(widget.serverId)).kind;
    if (host == null) return;
    try {
      if (kind == 'disk') {
        final pools = virtDiskStorages(
          await ref.read(virtStoragePoolsProvider(widget.serverId).future),
          host: host,
          kind: widget.guest.kind,
          node: widget.guest.node,
        );
        if (!mounted) return;
        // ignore: invalid_use_of_protected_member
        setState(() {
          _addPools = pools;
          _addPool = pools.firstOrNull;
        });
      } else if (_nets == null) {
        await _loadNets(host);
        if (!mounted) return;
        // ignore: invalid_use_of_protected_member
        setState(() => _addNet = _nets?.firstOrNull);
      }
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e) {
      Toast.error(libL10n.fail, body: '$e');
    }
  }

  Future<void> _loadNets(VirtHostKind host) async {
    final nets = virtCreateNetworks(
      await ref.read(virtNetworksProvider(widget.serverId).future),
      host: host,
      node: widget.guest.node,
    );
    if (!mounted) return;
    // ignore: invalid_use_of_protected_member
    setState(() => _nets = nets);
  }

  Future<List<VirtVolume>> _loadIsos() async {
    final host = ref.read(virtHostProvider(widget.serverId)).kind;
    if (host == null) return const [];
    final pools = await ref.read(
      virtStoragePoolsProvider(widget.serverId).future,
    );
    final lists = await Future.wait([
      for (final p in virtMediaStorages(
        pools,
        host: host,
        kind: VirtGuestKind.qemu,
        node: widget.guest.node,
      ))
        _notifier.volumes(p).catchError((Object _) => <VirtVolume>[]),
    ]);
    return [
      for (final list in lists)
        for (final v in list)
          if (virtIsMedia(v, VirtGuestKind.qemu)) v,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _pickCpuType(VirtHardware hw) async {
    final picked = await context.showRoundDialog<String>(
      title: l10n.virtHwModel,
      child: SizedBox(
        width: 400,
        height: 420,
        child: ListView(
          children: [
            for (final t in hw.cpuTypes)
              ListTile(
                key: ValueKey('hw:cputype:$t'),
                dense: true,
                title: Text(t, style: UIs.text13),
                selected: t == hw.cpu.type,
                onTap: () => context.popDialog(t),
              ),
          ],
        ),
      ),
      actions: [Btn.cancel()],
    );
    if (picked == null || picked == hw.cpu.type || !mounted) return;
    await _apply(
      hw,
      VirtHwSetCpu(
        sockets: hw.cpu.sockets,
        cores: hw.cpu.cores,
        online: hw.cpu.online,
        type: picked,
      ),
    );
  }

  Future<void> _removeDisk(VirtHardware hw, VirtHwDisk d) async {
    final cdrom = d.kind == VirtHwDiskKind.cdrom;
    var delete = false;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (context, setDialog) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.virtHwRemoveDiskAsk(d.key, widget.guest.name)),
            if (!cdrom && d.source != null)
              CheckboxListTile(
                key: const ValueKey('hw:disk:delete-volume'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: delete,
                title: Text(l10n.virtHwDeleteVolume),
                subtitle: Text(d.source!, style: UIs.text12Grey),
                onChanged: (v) => setDialog(() => delete = v ?? false),
              ),
          ],
        ),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    await _apply(hw, VirtHwRemoveDisk(key: d.key, deleteVolume: delete));
  }

  Future<void> _openAddDevice(VirtHwDeviceKind kind) async {
    // ignore: invalid_use_of_protected_member
    setState(() {
      _adding = 'dev';
      _devKind = kind;
      _devPick = null;
      _addPools = null;
      _addPool = null;
      _hostDevs ??= _notifier.hostDevices(widget.guest.id);
    });
    // The TPM's state is a volume on PVE: where it goes is asked.
    if (_pve) await _loadDiskPools();
  }

  Future<void> _loadDiskPools() async {
    final host = _host;
    if (host == null) return;
    try {
      final pools = virtDiskStorages(
        await ref.read(virtStoragePoolsProvider(widget.serverId).future),
        host: host,
        kind: widget.guest.kind,
        node: widget.guest.node,
      );
      if (!mounted) return;
      // ignore: invalid_use_of_protected_member
      setState(() {
        _addPools = pools;
        _addPool ??= pools.firstOrNull;
      });
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    }
  }

  Future<void> _removeDevice(VirtHardware hw, VirtHwDevice d) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        l10n.virtHwRemoveNicAsk(
          '${_deviceName(d.kind)} ${d.detail ?? ''}'.trim(),
          widget.guest.name,
        ),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    await _apply(hw, VirtHwRemoveDevice(key: d.key));
  }

  /// A new MAC: typed, or generated in the range the host uses for its own
  /// (PVE's `BC:24:11`, QEMU's `52:54:00`).
  Future<void> _editMac(VirtHardware hw, VirtHwNic n) async {
    final ctrl = TextEditingController(text: n.mac);
    String generate() {
      final r = Random.secure();
      String b() => r.nextInt(256).toRadixString(16).padLeft(2, '0');
      return '${_pve ? 'bc:24:11' : '52:54:00'}:${b()}:${b()}:${b()}';
    }

    final mac = await context.showRoundDialog<String>(
      title: l10n.virtHwMac,
      child: DisposeWith(
        notifiers: [ctrl],
        child: StatefulBuilder(
          builder: (context, setDialog) {
            final ok = virtIsUnicastMac(ctrl.text.trim());
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Input(
                  controller: ctrl,
                  label: l10n.virtHwMac,
                  icon: Icons.fingerprint,
                  suggestion: false,
                  onChanged: (_) => setDialog(() {}),
                ),
                if (!ok) Text(l10n.virtHwIssueMac, style: UIs.text12Grey),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Btn.text(
                    text: l10n.virtHwMacGenerate,
                    onTap: () => setDialog(() => ctrl.text = generate()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        Btn.cancel(),
        Btn.text(
          text: libL10n.save,
          onTap: () => context.popDialog(ctrl.text.trim()),
        ),
      ],
    );
    if (mac == null || !mounted) return;
    if (mac.toLowerCase() == n.mac?.toLowerCase()) return;
    final change = VirtHwSetNicHardware(key: n.key, mac: mac);
    if (_issueText(hw, virtHwIssue(hw, change, host: _host)) case final t?) {
      Toast.error(t);
      return;
    }
    await _apply(hw, change);
  }

  /// Switches the firmware after saying what it does to an installed
  /// system. On PVE a new EFI variables disk goes where the old one was, or
  /// on a storage picked here.
  Future<void> _setFirmware(
    VirtHardware hw, {
    required bool uefi,
    required bool secureBoot,
  }) async {
    final name = uefi ? (secureBoot ? 'UEFI · Secure Boot' : 'UEFI') : 'BIOS';
    final ok = await context.showRoundDialog<bool>(
      title: l10n.virtHwFirmwareWarnTitle,
      child: Text(
        '${l10n.virtHwSwitchFirmwareAsk(widget.guest.name, name)}\n\n'
        '${l10n.virtHwFirmwareWarnBody}',
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    String? storage = hw.firmware?.varsStorage;
    if (_pve && uefi && storage == null) {
      await _loadDiskPools();
      if (!mounted) return;
      final pools = _addPools ?? const [];
      final picked = await context.showPickSingleDialog<VirtStoragePool>(
        title: l10n.virtHwEfiStorage,
        items: pools,
        display: (p) => '${p.name} · ${p.type}',
      );
      if (picked == null || !mounted) return;
      storage = picked.name;
    }
    await _apply(
      hw,
      VirtHwSetFirmware(uefi: uefi, secureBoot: secureBoot, storage: storage),
    );
  }

  Future<void> _removeNic(VirtHardware hw, VirtHwNic n, String name) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.virtHwRemoveNicAsk(name, widget.guest.name)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    await _apply(hw, VirtHwRemoveNic(key: n.key));
  }
}

extension on String {
  /// This, or [other] when this is empty.
  String ifEmpty(String other) => isEmpty ? other : this;
}
