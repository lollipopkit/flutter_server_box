import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

import '../../../core/route.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/server/private_key_info.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/provider/private_key.dart';
import '../../../data/provider/server.dart';
import '../../../data/res/ui.dart';
import '../../../data/store/private_key.dart';
import '../../../locator.dart';
import '../../widget/tag_editor.dart';
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
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
    _focusScope = FocusScope.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildForm(),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final delBtn = IconButton(
      onPressed: () {
        showRoundDialog(
          context: context,
          title: Text(_s.attention),
          child: Text(_s.sureToDeleteServer(widget.spi!.name)),
          actions: [
            TextButton(
              onPressed: () {
                _serverProvider.delServer(widget.spi!.id);
                context.pop();
                context.pop();
              },
              child: Text(
                _s.ok,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(_s.cancel),
            )
          ],
        );
      },
      icon: const Icon(Icons.delete),
    );
    final actions = widget.spi != null ? [delBtn] : null;
    return AppBar(
      title: Text(_s.edit, style: textSize18),
      actions: actions,
    );
  }

  Widget _buildForm() {
    final children = [
      Input(
        controller: _nameController,
        type: TextInputType.text,
        node: _nameFocus,
        onSubmitted: (_) => _focusScope.requestFocus(_ipFocus),
        hint: _s.exampleName,
        label: _s.name,
        icon: Icons.info,
      ),
      Input(
        controller: _ipController,
        type: TextInputType.text,
        onSubmitted: (_) => _focusScope.requestFocus(_portFocus),
        node: _ipFocus,
        label: _s.host,
        icon: Icons.storage,
        hint: 'example.com',
      ),
      Input(
        controller: _portController,
        type: TextInputType.number,
        node: _portFocus,
        onSubmitted: (_) => _focusScope.requestFocus(_usernameFocus),
        label: _s.port,
        icon: Icons.format_list_numbered,
        hint: '22',
      ),
      Input(
        controller: _usernameController,
        type: TextInputType.text,
        node: _usernameFocus,
        label: _s.user,
        icon: Icons.account_box,
        hint: 'root',
      ),
      TagEditor(
        tags: _tags,
        onChanged: (p0) => setState(() {
          _tags = p0;
        }),
        s: _s,
        tagSuggestions: [..._serverProvider.tags],
        onRenameTag: _serverProvider.renameTag,
      ),
      width7,
      Row(
        children: [
          width13,
          Text(_s.keyAuth),
          width13,
          Switch(
            value: usePublicKey,
            onChanged: (val) => setState(() => usePublicKey = val),
          ),
        ],
      ),
    ];
    if (usePublicKey) {
      children.add(_buildKeyAuth());
    } else {
      children.add(Input(
        controller: _passwordController,
        obscureText: true,
        type: TextInputType.text,
        label: _s.pwd,
        icon: Icons.password,
        hint: _s.pwd,
        onSubmitted: (_) => {},
      ));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 47),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildKeyAuth() {
    return Consumer<PrivateKeyProvider>(
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
        return RoundRectCard(
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Column(
                children: tiles,
              )),
        );
      },
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'server',
      child: const Icon(Icons.save),
      onPressed: () async {
        if (_ipController.text == '') {
          showSnackBar(context, Text(_s.plzEnterHost));
          return;
        }
        if (!usePublicKey && _passwordController.text == '') {
          final cancel = await showRoundDialog<bool>(
            context: context,
            child: Text(_s.sureNoPwd),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: Text(_s.ok),
              ),
              TextButton(
                onPressed: () => context.pop(true),
                child: Text(_s.cancel),
              )
            ],
          );
          if (cancel ?? true) {
            return;
          }
        }
        if (usePublicKey && _pubKeyIndex == -1) {
          showSnackBar(context, Text(_s.plzSelectKey));
          return;
        }
        if (_usernameController.text.isEmpty) {
          _usernameController.text = 'root';
        }
        if (_portController.text.isEmpty) {
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
          tags: _tags,
        );

        if (widget.spi == null) {
          _serverProvider.addServer(spi);
        } else {
          _serverProvider.updateServer(widget.spi!, spi);
        }

        context.pop();
      },
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
      if (widget.spi?.tags != null) {
        _tags = widget.spi!.tags!;
      }
      setState(() {});
    }
  }
}
