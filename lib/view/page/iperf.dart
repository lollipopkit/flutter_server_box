import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/src/rust/api/iperf.dart' as ffi;
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
    final portText = _portCtrl.text.trim();
    if (rawHost.isEmpty || portText.isEmpty) {
      Toast.show(libL10n.empty);
      return;
    }
    final host = ffi.iperfNormalizeHost(raw: rawHost);
    if (host == null) {
      Toast.error(l10n.invalidHostFormat);
      return;
    }
    final port = ffi.iperfValidPort(raw: portText);
    if (port == null) {
      Toast.error('${libL10n.invalid}: ${libL10n.port}');
      return;
    }
    final args = SshPageArgs(
      source: ServerSource(widget.args.spi),
      initCmd: ffi.iperfClientCommand(host: host, port: port),
    );
    SSHPage.route.go(context, args);
  }
}
