import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/view/widget/appbar.dart';
import 'package:toolbox/view/widget/input_field.dart';

class IPerfPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const IPerfPage({super.key, required this.spi});

  @override
  State<IPerfPage> createState() => _IPerfPageState();
}

class _IPerfPageState extends State<IPerfPage> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('iperf'),
      ),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'iperf',
      child: const Icon(Icons.send),
      onPressed: () {
        if (_hostCtrl.text.isEmpty || _portCtrl.text.isEmpty) {
          context.showSnackBar(l10n.fieldMustNotEmpty);
          return;
        }
        AppRoute.ssh(
          spi: widget.spi,
          initCmd: 'iperf -c ${_hostCtrl.text} -p ${_portCtrl.text}',
        ).go(context);
      },
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      children: [
        Input(
          controller: _hostCtrl,
          label: l10n.host,
          icon: Icons.computer,
        ),
        Input(
          controller: _portCtrl,
          label: l10n.port,
          type: TextInputType.number,
          icon: Icons.numbers,
        ),
      ],
    );
  }
}
