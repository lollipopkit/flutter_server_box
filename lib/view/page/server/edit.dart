import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server_private_info.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/private_key/edit.dart';
import 'package:toolbox/view/widget/input_decoration.dart';

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

  int _typeOptionIndex = -1;
  final List<String> _keyInfo = ['', ''];

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit'), actions: [
        widget.spi != null
            ? IconButton(
                onPressed: () {
                  _serverProvider.delServer(widget.spi!);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete))
            : const SizedBox()
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              keyboardType: TextInputType.text,
              decoration: buildDecoration('Name', icon: Icons.info),
            ),
            TextField(
              controller: ipController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              decoration: buildDecoration('Host', icon: Icons.storage),
            ),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration:
                  buildDecoration('Port', icon: Icons.format_list_numbered),
            ),
            TextField(
              controller: usernameController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              decoration: buildDecoration('User', icon: Icons.account_box),
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
            !usePublicKey
                ? TextField(
                    controller: passwordController,
                    obscureText: true,
                    keyboardType: TextInputType.text,
                    decoration: buildDecoration('Pwd', icon: Icons.password),
                    onSubmitted: (_) => {},
                  )
                : const SizedBox(),
            usePublicKey
                ? Consumer<PrivateKeyProvider>(builder: (_, key, __) {
                    final tiles = key.infos
                        .map(
                          (e) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.id, textAlign: TextAlign.start),
                              trailing: _buildRadio(key.infos.indexOf(e),
                                  e.privateKey, e.password)),
                        )
                        .toList();
                    tiles.add(ListTile(
                      title: const Text('Add a Private Key'),
                      contentPadding: EdgeInsets.zero,
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => AppRoute(const PrivateKeyEditPage(),
                                'private key edit page')
                            .go(context),
                      ),
                    ));
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text(
                        'Choose Key',
                        style: TextStyle(fontSize: 14),
                      ),
                      children: tiles,
                    );
                  })
                : const SizedBox()
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.send),
        onPressed: () {
          if (usePublicKey && _typeOptionIndex == -1) {
            showSnackBar(context, const Text('Please select a private key.'));
          }
          final authorization = usePublicKey
              ? {"privateKey": _keyInfo[0], "passphrase": _keyInfo[1]}
              : passwordController.text;
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

  Radio _buildRadio(int index, String key, String pwd) {
    return Radio<int>(
      value: index,
      groupValue: _typeOptionIndex,
      onChanged: (int? value) {
        setState(() {
          _typeOptionIndex = value!;
          _keyInfo[0] = key;
          _keyInfo[1] = pwd;
        });
      },
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
