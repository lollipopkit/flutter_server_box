import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/server/firewalld.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/ufw.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/firewall.dart';

part 'common.dart';
part 'firewalld.dart';
part 'ufw.dart';

/// A server's firewall: ufw or firewalld, whichever it has.
///
/// This page only finds out which, and how this app reaches the server; the
/// firewall's own page takes it from there. Both check every change against
/// that before making it.
final class FirewallPage extends ConsumerStatefulWidget {
  const FirewallPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: FirewallPage.new,
    path: '/firewall',
  );

  @override
  ConsumerState<FirewallPage> createState() => _FirewallPageState();
}

final class _FirewallPageState extends ConsumerState<FirewallPage> {
  late final _provider = serverProvider(widget.args.spi.id);

  FirewallProbeResult? _probe;
  FirewallKind? _kind;
  bool _unsupported = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    Future.microtask(_runProbe);
  }

  @override
  Widget build(BuildContext context) {
    final probe = _probe;
    final kind = _kind;
    if (probe != null && kind != null) {
      final host = _FirewallHost(
        spi: widget.args.spi,
        probe: probe,
        accesses: _accessesFor(widget.args.spi, probe),
        onSwitch: (kind) => setState(() => _kind = kind),
      );
      return switch (kind) {
        FirewallKind.ufw => _UfwView(key: const ValueKey('ufw'), host: host),
        FirewallKind.firewalld => _FirewalldView(
          key: const ValueKey('firewalld'),
          host: host,
        ),
      };
    }

    final Widget body;
    if (_unsupported) {
      body = _issueBody(
        context,
        title: libL10n.unsupported,
        explain: l10n.firewallLinuxOnly,
        icon: Icons.not_interested,
        onRetry: _runProbe,
      );
    } else if (_failure case final failure?) {
      body = _issueBody(
        context,
        title: libL10n.fail,
        detail: failure,
        icon: Icons.error_outline,
        onRetry: _runProbe,
      );
    } else if (probe != null) {
      body = _issueBody(
        context,
        title: libL10n.unsupported,
        explain: l10n.firewallNoneInstalled,
        icon: Icons.shield_outlined,
        onRetry: _runProbe,
      );
    } else {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 280, child: UIs.centerLoading)],
      );
    }
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: l10n.firewall, down: widget.args.spi.name),
      ),
      body: RefreshIndicator(onRefresh: _runProbe, child: body),
    );
  }

  Future<void> _runProbe() async {
    if (!mounted) return;
    if (ref.read(_provider).status.system != SystemType.linux) {
      setState(() => _unsupported = true);
      return;
    }
    setState(() {
      _unsupported = false;
      _failure = null;
      _probe = null;
    });
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      final probe = await FirewallProbe.run(exec);
      if (!mounted) return;
      setState(() {
        _probe = probe;
        _kind = probe.preferred;
      });
    } catch (e, s) {
      Loggers.app.warning('Probe firewall on ${widget.args.spi.id}', e, s);
      if (mounted) setState(() => _failure = '$e');
    }
  }
}

/// The ways this app reaches [spi], each a port a firewall change could shut.
///
/// SSH's as the server saw the probe arrive, where it arrived over SSH: the
/// port behind any NAT, the address it came from and the interface it came
/// in on. The agent's from its
/// address; what is in front of it — a reverse proxy, a NAT — is not known.
/// None for this device.
List<FirewallAccess> _accessesFor(Spi spi, FirewallProbeResult probe) => [
  if (spi.sshOn case final ssh?)
    probe.ssh ?? FirewallAccess(via: FirewallAccessVia.ssh, port: ssh.port),
  if (spi.monitorOn case final monitor?)
    if (Uri.tryParse(monitor.addr) case final uri? when uri.hasAuthority)
      FirewallAccess(via: FirewallAccessVia.monitor, port: uri.port),
];
