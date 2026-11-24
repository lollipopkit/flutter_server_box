import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/bmc/common.dart';

/// The drives the BMC sees, whatever the host OS is doing: the ones to look
/// at first.
final class BmcDrivesPage extends ConsumerStatefulWidget {
  final BmcTargetRequiredArgs args;

  const BmcDrivesPage({super.key, required this.args});

  static const route = AppRouteArg<void, BmcTargetRequiredArgs>(
    page: BmcDrivesPage.new,
    path: '/server/bmc/drives',
  );

  @override
  ConsumerState<BmcDrivesPage> createState() => _BmcDrivesPageState();
}

final class _BmcDrivesPageState extends ConsumerState<BmcDrivesPage> {
  StorageReport? _report;
  String? _loadedAddr;
  String? _activeAddr;
  String? _err;
  var _loading = false;
  var _read = 0;

  String get _targetId => widget.args.target.id;
  BmcTarget get _currentTarget =>
      ref.read(bmcTargetsProvider).targets[_targetId] ?? widget.args.target;

  @override
  void initState() {
    super.initState();
    _activeAddr = _currentTarget.addr.trim();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final target = ref.watch(
      bmcTargetsProvider.select(
        (s) => s.targets[_targetId] ?? widget.args.target,
      ),
    );
    final currentAddr = target.addr.trim();
    if (_activeAddr != currentAddr) {
      _activeAddr = currentAddr;
      _read++;
      _report = null;
      _loadedAddr = null;
      _err = null;
      _loading = true;
      Future.microtask(_load);
    }
    // Watched so the session lives while this page does.
    ref.watch(bmcProvider(_targetId).select((s) => s.hasData));
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: l10n.bmcDrives, down: target.name),
        actions: [
          Btn.icon(
            text: libL10n.refresh,
            icon: const Icon(Icons.refresh),
            onTap: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(currentAddr),
    );
  }

  Widget _buildBody(String currentAddr) {
    final report = _loadedAddr == currentAddr ? _report : null;
    if (report == null) {
      return Center(
        child: _err == null
            ? SizedLoading.medium
            : Padding(
                padding: const EdgeInsets.all(17),
                child: Text(_err!, textAlign: TextAlign.center),
              ),
      );
    }
    if (report.unsupported) return Center(child: Text(l10n.bmcNoStorage));
    if (report.drives.isEmpty && _err == null) {
      return Center(child: Text(libL10n.empty));
    }
    // Failing first: what anyone opens this for.
    final drives = [
      ...report.drives.where((d) => d.needsAttention),
      ...report.drives.where((d) => !d.needsAttention),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 17),
      children: [
        // The last answer, and why it may be old.
        if (_err != null) _buildNotice(_err!, bad: true),
        for (final d in drives) _buildDrive(d),
        if (report.truncated) _buildNotice(l10n.bmcDrivesTruncated),
      ],
    );
  }

  Widget _buildNotice(String text, {bool bad = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
    child: Text(
      text,
      style: bad ? const TextStyle(color: Colors.red) : UIs.text12Grey,
      textAlign: TextAlign.center,
    ),
  );

  Widget _buildDrive(Drive d) {
    final color = d.needsAttention
        ? bmcHealthColor(d.health) ?? Colors.red
        : null;
    final life = d.lifeLeftPercent;
    final sub = [
      d.capacityBytes?.bytes2Str,
      d.mediaType,
      d.protocol,
      if (life != null) '${life.toStringAsFixed(0)}%',
      d.controller,
      d.serial,
    ].nonNulls.where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      leading: Icon(
        d.mediaType == 'SSD' ? Icons.sd_storage : Icons.storage,
        color: color,
      ),
      title: Text(d.model ?? d.name ?? libL10n.unknown),
      subtitle: sub.isEmpty ? null : Text(sub, style: UIs.text12Grey),
      trailing: switch ((d.failurePredicted, d.health, d.state)) {
        (true, _, _) => Icon(Icons.warning, color: color),
        (_, final health?, _) => Text(health, style: TextStyle(color: color)),
        (_, _, final state?) => Text(state, style: UIs.text12Grey),
        _ => null,
      },
    );
  }

  Future<void> _load() async {
    final addr = _currentTarget.addr.trim();
    final read = ++_read;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final report = await ref.read(bmcProvider(_targetId).notifier).storage();
      if (!mounted || read != _read || _currentTarget.addr.trim() != addr) {
        return;
      }
      setState(() {
        _report = report;
        _loadedAddr = addr;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || read != _read || _currentTarget.addr.trim() != addr) {
        return;
      }
      setState(() {
        _err = bmcErrorText(e);
        _loading = false;
      });
    }
  }
}
