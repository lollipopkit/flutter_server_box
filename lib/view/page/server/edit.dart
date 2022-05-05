import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/generated/l10n.dart';
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

  late S s;

  bool usePublicKey = false;

  int _pubKeyIndex = -1;
  PrivateKeyInfo? _keyInfo;

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.edit, style: size18), actions: [
        widget.spi != null
            ? IconButton(
                onPressed: () {
                  showRoundDialog(context, 'Attention',
                      Text(s.sureToDeleteServer(widget.spi!.name)), [
                    TextButton(
                        onPressed: () {
                          _serverProvider.delServer(widget.spi!);
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          s.ok,
                          style: const TextStyle(color: Colors.red),
                        )),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(s.cancel))
                  ]);
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
              decoration: buildDecoration(s.name,
                  icon: Icons.info, hint: s.exampleName),
            ),
            TextField(
              controller: ipController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              decoration: buildDecoration(s.host,
                  icon: Icons.storage, hint: 'example.com'),
            ),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: buildDecoration(s.port,
                  icon: Icons.format_list_numbered, hint: '22'),
            ),
            TextField(
              controller: usernameController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              decoration: buildDecoration(s.user,
                  icon: Icons.account_box, hint: 'root'),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(s.keyAuth),
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
                    decoration: buildDecoration(s.pwd,
                        icon: Icons.password, hint: s.pwd),
                    onSubmitted: (_) => {},
                  )
                : const SizedBox(),
            usePublicKey
                ? Consumer<PrivateKeyProvider>(builder: (_, key, __) {
                    for (var item in key.infos) {
                      if (item.id == widget.spi?.pubKeyId) {
                        _pubKeyIndex = key.infos.indexOf(item);
                      }
                    }
                    final tiles = key.infos
                        .map(
                          (e) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.id, textAlign: TextAlign.start),
                              trailing: _buildRadio(key.infos.indexOf(e), e)),
                        )
                        .toList();
                    tiles.add(ListTile(
                      title: Text(s.addPrivateKey),
                      contentPadding: EdgeInsets.zero,
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => AppRoute(const PrivateKeyEditPage(),
                                'private key edit page')
                            .go(context),
                      ),
                    ));
                    return ExpansionTile(
                      textColor: primaryColor,
                      iconColor: primaryColor,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        s.choosePrivateKey,
                        style: const TextStyle(fontSize: 14),
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
          if (ipController.text == '') {
            showSnackBar(context, Text(s.plzEnterHost));
            return;
          }
          if (!usePublicKey && passwordController.text == '') {
            showSnackBar(context, Text(s.plzEnterPwd));
            return;
          }
          if (usePublicKey && _pubKeyIndex == -1) {
            showSnackBar(context, Text(s.plzSelectKey));
            return;
          }
          if (usernameController.text == '') {
            usernameController.text = 'root';
          }
          if (portController.text == '') {
            portController.text = '22';
          }

          if (widget.spi != null && widget.spi!.pubKeyId != null) {
            _keyInfo ??= locator<PrivateKeyStore>().get(widget.spi!.pubKeyId!);
          }

          final authorization = usePublicKey
              ? {
                  "privateKey": _keyInfo!.privateKey,
                  "passphrase": _keyInfo!.password
                }
              : passwordController.text;
          final spi = ServerPrivateInfo(
              name: nameController.text,
              ip: ipController.text,
              port: int.parse(portController.text),
              user: usernameController.text,
              authorization: authorization,
              pubKeyId: usePublicKey ? _keyInfo!.id : null);

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

  Radio _buildRadio(int index, PrivateKeyInfo pki) {
    return Radio<int>(
      value: index,
      groupValue: _pubKeyIndex,
      onChanged: (int? value) {
        setState(() {
          _pubKeyIndex = value!;
          _keyInfo = pki;
        });
      },
    );
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
        usePublicKey = true;
      }
      setState(() {});
    }
  }
}
