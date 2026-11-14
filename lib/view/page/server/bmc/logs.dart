import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/bmc/common.dart';

/// The logs a BMC keeps — the machine's event log first, then the BMC's own —
/// one at a time, newest entry first.
final class BmcLogsPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const BmcLogsPage({super.key, required this.args});

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: BmcLogsPage.new,
    path: '/server/bmc/logs',
  );

  @override
  ConsumerState<BmcLogsPage> createState() => _BmcLogsPageState();
}

final class _BmcLogsPageState extends ConsumerState<BmcLogsPage> {
  List<LogService>? _services;
  LogService? _picked;
  LogPage? _page;
  String? _err;
  var _loading = false;

  /// Rises on every read, so a slow answer for a log no longer picked is
  /// dropped.
  var _read = 0;

  Spi get _spi => widget.args.spi;
  BmcNotifier get _bmc => ref.read(bmcProvider(_spi).notifier);

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadServices);
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the session lives while this page does.
    ref.watch(bmcProvider(_spi).select((s) => s.hasData));
    final picked = _picked;
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: libL10n.logs, down: _spi.name),
        actions: [
          if (picked?.clearTarget != null)
            Btn.icon(
              text: libL10n.clear,
              icon: const Icon(Icons.delete_sweep),
              onTap: _loading ? null : () => _clear(picked!),
            ),
          Btn.icon(
            text: libL10n.refresh,
            icon: const Icon(Icons.refresh),
            onTap: _loading ? null : _reload,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final services = _services;
    if (services == null) {
      return _err != null ? _buildErr() : _buildLoading();
    }
    if (services.isEmpty) return Center(child: Text(libL10n.empty));
    return Column(
      children: [
        if (services.length > 1) _buildPicker(services),
        // The last read, and why it may be old.
        if (_page != null && _err != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
            child: Text(
              _err!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(child: _buildEntries()),
      ],
    );
  }

  Widget _buildLoading() => const Center(child: SizedLoading.medium);

  Widget _buildErr() => Center(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Text(_err!, textAlign: TextAlign.center),
    ),
  );

  Widget _buildPicker(List<LogService> services) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Row(
        spacing: 7,
        children: [
          for (final s in services)
            ChoiceChip(
              label: Text(_serviceName(s)),
              selected: s == _picked,
              onSelected: (_) => _pick(s),
            ),
        ],
      ),
    );
  }

  Widget _buildEntries() {
    final page = _page;
    if (page == null) return _err != null ? _buildErr() : _buildLoading();
    final entries = page.entries;
    if (entries.isEmpty && !page.truncated) {
      return Center(child: Text(libL10n.empty));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 17),
      itemCount: entries.length + (page.truncated ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == entries.length) {
          return Padding(
            padding: const EdgeInsets.all(13),
            child: Text(
              l10n.bmcEntriesTruncated,
              style: UIs.text12Grey,
              textAlign: TextAlign.center,
            ),
          );
        }
        return _buildEntry(entries[i]);
      },
    );
  }

  Widget _buildEntry(LogEntry e) {
    final color = bmcHealthColor(e.severity);
    final created = e.created == null ? null : DateTime.tryParse(e.created!);
    final sub = [
      created?.toLocal().ymdhms() ?? e.created,
      e.messageId,
    ].nonNulls.join('  ');
    return ListTile(
      leading: Icon(switch (e.severity) {
        'Critical' => Icons.error,
        'Warning' => Icons.warning,
        _ => Icons.info_outline,
      }, color: color),
      title: Text(e.message ?? e.messageId ?? e.id ?? '', maxLines: 4),
      subtitle: sub.isEmpty ? null : Text(sub, style: UIs.text12Grey),
    );
  }

  String _serviceName(LogService s) => s.name ?? s.id ?? s.path;

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final services = await _bmc.logServices();
      if (!mounted) return;
      setState(() {
        _services = services;
        _loading = false;
      });
      if (services.isNotEmpty) await _pick(services.first);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = bmcErrorText(e);
        _loading = false;
      });
    }
  }

  /// Reads [service]. [keep] leaves what is shown up while it is read again,
  /// so a refresh that fails leaves the entries it has, with the reason.
  Future<void> _pick(LogService service, {bool keep = false}) async {
    final read = ++_read;
    setState(() {
      _picked = service;
      if (!keep) _page = null;
      _err = null;
      _loading = true;
    });
    try {
      final page = await _bmc.logEntries(service);
      if (!mounted || read != _read) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || read != _read) return;
      setState(() {
        _err = bmcErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    final picked = _picked;
    if (_services == null || picked == null) return _loadServices();
    await _pick(picked, keep: true);
  }

  Future<void> _clear(LogService service) async {
    final ok = await context.showSheet<bool>(
      title: libL10n.clear,
      child: Text(l10n.bmcClearLogConfirm(_serviceName(service), _spi.name)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    if (await context.bmcRun(() => _bmc.clearLog(service)) && mounted) {
      await _pick(service, keep: true);
    }
  }
}
