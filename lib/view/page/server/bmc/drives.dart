import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/bmc/common.dart';

/// The drives the BMC sees, whatever the host OS is doing: the ones to look
/// at first.
final class BmcDrivesPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const BmcDrivesPage({super.key, required this.args});

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: BmcDrivesPage.new,
    path: '/server/bmc/drives',
  );

  @override
  ConsumerState<BmcDrivesPage> createState() => _BmcDrivesPageState();
}

final class _BmcDrivesPageState extends ConsumerState<BmcDrivesPage> {
  StorageReport? _report;
  String? _err;
  var _loading = false;

  Spi get _spi => widget.args.spi;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the session lives while this page does.
    ref.watch(bmcProvider(_spi).select((s) => s.hasData));
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: l10n.bmcDrives, down: _spi.name),
        actions: [
          Btn.icon(
            text: libL10n.refresh,
            icon: const Icon(Icons.refresh),
            onTap: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final report = _report;
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
    if (report.drives.isEmpty) return Center(child: Text(libL10n.empty));
    // Failing first: what anyone opens this for.
    final drives = [
      ...report.drives.where((d) => d.needsAttention),
      ...report.drives.where((d) => !d.needsAttention),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 17),
      children: [
        for (final d in drives) _buildDrive(d),
      ],
    );
  }

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
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final report = await ref.read(bmcProvider(_spi).notifier).storage();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = bmcErrorText(e);
        _loading = false;
      });
    }
  }
}
