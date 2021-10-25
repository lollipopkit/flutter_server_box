import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/data/model/server_private_info.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';

class ServerEditPage extends StatefulWidget {
  const ServerEditPage({Key? key, this.spi}) : super(key: key);

  final ServerPrivateInfo? spi;

  @override
  _ServerEditPageState createState() => _ServerEditPageState();
}

class _ServerEditPageState extends State<ServerEditPage> with AfterLayoutMixin {
  final nameController = TextEditingController();
  final ipController = TextEditingController();
  final portController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final keyController = TextEditingController();

  late ServerProvider _serverProvider;

  bool usePublicKey = false;

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              keyboardType: TextInputType.text,
              decoration: _buildDecoration('Name', icon: Icons.info),
            ),
            TextField(
              controller: ipController,
              keyboardType: TextInputType.text,
              decoration: _buildDecoration('Host', icon: Icons.storage),
            ),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration:
                  _buildDecoration('Port', icon: Icons.format_list_numbered),
            ),
            TextField(
              controller: usernameController,
              keyboardType: TextInputType.text,
              decoration: _buildDecoration('User', icon: Icons.account_box),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                const Text('Public Key Auth'),
                Switch(
                    value: usePublicKey,
                    onChanged: (val) => setState(() => usePublicKey = val)),
              ],
            ),
            usePublicKey
                ? TextField(
                    controller: keyController,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    maxLines: 10,
                    minLines: 5,
                    decoration:
                        _buildDecoration('Private Key', icon: Icons.vpn_key),
                    onSubmitted: (_) => {},
                  )
                : const SizedBox(),
            TextField(
              controller: passwordController,
              obscureText: true,
              keyboardType: TextInputType.text,
              decoration: _buildDecoration('Pwd', icon: Icons.password),
              onSubmitted: (_) => {},
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.send),
        onPressed: () {
          final authorization = keyController.text.isEmpty
              ? passwordController.text
              : {
                  "privateKey": keyController.text,
                  "passphrase": passwordController.text
                };
          final spi = ServerPrivateInfo(
              name: nameController.text,
              ip: ipController.text,
              port: int.parse(portController.text),
              user: usernameController.text,
              authorization: authorization);

          if (widget.spi == null) {
            _serverProvider.addServer(spi);
          } else {
            _serverProvider.updateServer(widget.spi!, spi);
          }

          Navigator.of(context).pop();
        },
      ),
    );
  }

  InputDecoration _buildDecoration(String label,
      {TextStyle? textStyle, IconData? icon}) {
    return InputDecoration(
        labelText: label, labelStyle: textStyle, icon: Icon(icon));
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (widget.spi != null) {
      nameController.text = widget.spi?.name ?? '';
      ipController.text = widget.spi?.ip ?? '';
      portController.text = (widget.spi?.port ?? 22).toString();
      usernameController.text = widget.spi?.user ?? '';
      if (widget.spi?.authorization is String) {
        passwordController.text = widget.spi?.authorization as String? ?? '';
      } else {
        final auth = widget.spi?.authorization as Map;
        passwordController.text = auth['passphrase'];
        keyController.text = auth['privateKey'];
        setState(() {
          usePublicKey = true;
        });
      }
    }
  }
}
