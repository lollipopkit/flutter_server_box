import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/route.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/server/private_key_info.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/provider/private_key.dart';
import '../../../data/provider/server.dart';
import '../../../data/res/color.dart';
import '../../../data/res/font_style.dart';
import '../../../data/store/private_key.dart';
import '../../../generated/l10n.dart';
import '../../../locator.dart';
import '../../widget/input_decoration.dart';
import '../private_key/edit.dart';

class ServerEditPage extends StatefulWidget {
  const ServerEditPage({Key? key, this.spi}) : super(key: key);

  final ServerPrivateInfo? spi;

  @override
  _ServerEditPageState createState() => _ServerEditPageState();
}

class _ServerEditPageState extends State<ServerEditPage> with AfterLayoutMixin {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _ipFocus = FocusNode();
  final _portFocus = FocusNode();
  final _usernameFocus = FocusNode();

  late FocusScopeNode _focusScope;
  late ServerProvider _serverProvider;
  late S _s;

  bool usePublicKey = false;
  int? _pubKeyIndex;
  PrivateKeyInfo? _keyInfo;

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context);
    _focusScope = FocusScope.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.edit, style: textSize18),
        actions: [
          widget.spi != null
              ? IconButton(
                  onPressed: () {
                    showRoundDialog(
                      context,
                      _s.attention,
                      Text(_s.sureToDeleteServer(widget.spi!.name)),
                      [
                        TextButton(
                          onPressed: () {
                            _serverProvider.delServer(widget.spi!);
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            _s.ok,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(_s.cancel),
                        )
                      ],
                    );
                  },
                  icon: const Icon(Icons.delete),
                )
              : const SizedBox()
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              keyboardType: TextInputType.text,
              focusNode: _nameFocus,
              onSubmitted: (_) => _focusScope.requestFocus(_ipFocus),
              decoration: buildDecoration(
                _s.name,
                icon: Icons.info,
                hint: _s.exampleName,
              ),
            ),
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.text,
              onSubmitted: (_) => _focusScope.requestFocus(_portFocus),
              focusNode: _ipFocus,
              autocorrect: false,
              enableSuggestions: false,
              decoration: buildDecoration(
                _s.host,
                icon: Icons.storage,
                hint: 'example.com',
              ),
            ),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              focusNode: _portFocus,
              onSubmitted: (_) => _focusScope.requestFocus(_usernameFocus),
              decoration: buildDecoration(
                _s.port,
                icon: Icons.format_list_numbered,
                hint: '22',
              ),
            ),
            TextField(
              controller: _usernameController,
              keyboardType: TextInputType.text,
              focusNode: _usernameFocus,
              autocorrect: false,
              enableSuggestions: false,
              decoration: buildDecoration(
                _s.user,
                icon: Icons.account_box,
                hint: 'root',
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(_s.keyAuth),
                Switch(
                  value: usePublicKey,
                  onChanged: (val) => setState(() => usePublicKey = val),
                ),
              ],
            ),
            !usePublicKey
                ? TextField(
                    controller: _passwordController,
                    obscureText: true,
                    keyboardType: TextInputType.text,
                    decoration: buildDecoration(
                      _s.pwd,
                      icon: Icons.password,
                      hint: _s.pwd,
                    ),
                    onSubmitted: (_) => {},
                  )
                : const SizedBox(),
            usePublicKey
                ? Consumer<PrivateKeyProvider>(
                    builder: (_, key, __) {
                      for (var item in key.infos) {
                        if (item.id == widget.spi?.pubKeyId) {
                          _pubKeyIndex ??= key.infos.indexOf(item);
                        }
                      }
                      final tiles = key.infos
                          .map(
                            (e) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.id, textAlign: TextAlign.start),
                              trailing: _buildRadio(key.infos.indexOf(e), e),
                            ),
                          )
                          .toList();
                      tiles.add(
                        ListTile(
                          title: Text(_s.addPrivateKey),
                          contentPadding: EdgeInsets.zero,
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => AppRoute(
                              const PrivateKeyEditPage(),
                              'private key edit page',
                            ).go(context),
                          ),
                        ),
                      );
                      return PrimaryColor(builder: ((context, primaryColor) {
                        return ExpansionTile(
                          textColor: primaryColor,
                          iconColor: primaryColor,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text(
                            _s.choosePrivateKey,
                            style: const TextStyle(fontSize: 14),
                          ),
                          children: tiles,
                        );
                      }));
                    },
                  )
                : const SizedBox()
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.send),
        onPressed: () async {
          if (_ipController.text == '') {
            showSnackBar(context, Text(_s.plzEnterHost));
            return;
          }
          if (!usePublicKey && _passwordController.text == '') {
            final cancel = await showRoundDialog<bool>(
              context,
              _s.attention,
              Text(_s.sureNoPwd),
              [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(_s.ok)),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(_s.cancel))
              ],
              barrierDismiss: false,
            );
            if (cancel ?? true) {
              return;
            }
          }
          if (usePublicKey && _pubKeyIndex == -1) {
            showSnackBar(context, Text(_s.plzSelectKey));
            return;
          }
          if (_usernameController.text == '') {
            _usernameController.text = 'root';
          }
          if (_portController.text == '') {
            _portController.text = '22';
          }

          if (widget.spi != null && widget.spi!.pubKeyId != null) {
            _keyInfo ??= locator<PrivateKeyStore>().get(widget.spi!.pubKeyId!);
          }

          final authorization = _passwordController.text;
          final spi = ServerPrivateInfo(
            name: _nameController.text,
            ip: _ipController.text,
            port: int.parse(_portController.text),
            user: _usernameController.text,
            pwd: authorization,
            pubKeyId: usePublicKey ? _keyInfo!.id : null,
          );

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
      _nameController.text = widget.spi?.name ?? '';
      _ipController.text = widget.spi?.ip ?? '';
      _portController.text = (widget.spi?.port ?? 22).toString();
      _usernameController.text = widget.spi?.user ?? '';
      if (widget.spi?.pubKeyId == null) {
        _passwordController.text = widget.spi?.pwd ?? '';
      } else {
        usePublicKey = true;
      }
      setState(() {});
    }
  }
}
