import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

class IPerfPage extends StatefulWidget {
  final SpiRequiredArgs args;

  const IPerfPage({super.key, required this.args});

  @override
  State<IPerfPage> createState() => _IPerfPageState();

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: IPerfPage.new,
    path: '/iperf',
  );
}

class _IPerfPageState extends State<IPerfPage> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: const Text('iperf')),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  bool _isValidHost(String v) {
    final s = v.trim();
    if (s.isEmpty || s.length > 253) return false;
    // No shell metachars, no whitespace, no semicolon/comment injection
    if (RegExp(r'[;&|`$()#\s]').hasMatch(s)) return false;
    // Allow hostname, IPv4, or bracketed IPv6.
    return RegExp(r'^[A-Za-z0-9._\-:\[\]]+$').hasMatch(s);
  }

  bool _isValidPort(String v) {
    final s = v.trim();
    if (s.isEmpty || s.length > 5) return false;
    if (!RegExp(r'^\d+$').hasMatch(s)) return false;
    final n = int.tryParse(s);
    return n != null && n >= 1 && n <= 65535;
  }

  String _shellSingleQuote(String v) => "'${v.replaceAll("'", "'\\''")}'";

  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'iperf',
      child: const Icon(Icons.send),
      onPressed: () {
        final host = _hostCtrl.text.trim();
        final port = _portCtrl.text.trim();
        if (host.isEmpty || port.isEmpty) {
          Toast.show(libL10n.empty);
          return;
        }
        if (!_isValidHost(host)) {
          Toast.error('Invalid host');
          return;
        }
        if (!_isValidPort(port)) {
          Toast.error('Port must be 1-65535');
          return;
        }
        final args = SshPageArgs(
          source: ServerSource(widget.args.spi),
          initCmd: 'iperf -c ${_shellSingleQuote(host)} -p ${_shellSingleQuote(port)}',
        );
        SSHPage.route.go(context, args);
      },
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      children: [
        Input(
          controller: _hostCtrl,
          label: libL10n.host,
          icon: Icons.computer,
          suggestion: false,
        ),
        Input(
          controller: _portCtrl,
          label: libL10n.port,
          type: TextInputType.number,
          icon: Icons.numbers,
          suggestion: false,
        ),
      ],
    );
  }
}
