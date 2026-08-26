import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

String? normalizeIperfHost(String value) {
  final host = value.trim();
  if (host.isEmpty || host.length > 253) return null;

  if (host.startsWith('[') || host.endsWith(']')) {
    if (!host.startsWith('[') || !host.endsWith(']')) return null;
    final address = InternetAddress.tryParse(
      host.substring(1, host.length - 1),
    );
    return address?.type == InternetAddressType.IPv6 ? address!.address : null;
  }

  final address = InternetAddress.tryParse(host);
  if (address != null) return address.address;
  if (host.contains(':')) return null;
  if (RegExp(r'^[0-9.]+$').hasMatch(host)) return null;

  final labels = host.split('.');
  if (labels.any((label) {
    return label.isEmpty ||
        label.length > 63 ||
        label.startsWith('-') ||
        label.endsWith('-') ||
        !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(label);
  })) {
    return null;
  }
  return host;
}

bool isValidIperfPort(String value) {
  final port = value.trim();
  if (port.isEmpty || port.length > 5 || !RegExp(r'^\d+$').hasMatch(port)) {
    return false;
  }
  final parsed = int.tryParse(port);
  return parsed != null && parsed >= 1 && parsed <= 65535;
}

String buildIperfClientCommand(String host, String port) {
  return 'iperf -c $host -p $port';
}

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
}

extension _Widgets on _IPerfPageState {
  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'iperf',
      onPressed: _onTapSend,
      child: const Icon(Icons.send),
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

extension _Actions on _IPerfPageState {
  void _onTapSend() {
    final rawHost = _hostCtrl.text.trim();
    final port = _portCtrl.text.trim();
    if (rawHost.isEmpty || port.isEmpty) {
      Toast.show(libL10n.empty);
      return;
    }
    final host = normalizeIperfHost(rawHost);
    if (host == null) {
      Toast.error(l10n.invalidHostFormat);
      return;
    }
    if (!isValidIperfPort(port)) {
      Toast.error('${libL10n.invalid}: ${libL10n.port}');
      return;
    }
    final args = SshPageArgs(
      source: ServerSource(widget.args.spi),
      initCmd: buildIperfClientCommand(host, port),
    );
    SSHPage.route.go(context, args);
  }
}
