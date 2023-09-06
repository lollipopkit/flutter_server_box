import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/context.dart';

import '../../../core/route.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/server/private_key_info.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/provider/private_key.dart';
import '../../../data/provider/server.dart';
import '../../../data/res/ui.dart';
import '../../../locator.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/input_field.dart';
import '../../widget/round_rect_card.dart';
import '../../widget/tag.dart';
import '../../widget/value_notifier.dart';

class ServerEditPage extends StatefulWidget {
  const ServerEditPage({Key? key, this.spi}) : super(key: key);

  final ServerPrivateInfo? spi;

  @override
  _ServerEditPageState createState() => _ServerEditPageState();
}

class _ServerEditPageState extends State<ServerEditPage> {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _altUrlController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _ipFocus = FocusNode();
  final _alterUrlFocus = FocusNode();
  final _portFocus = FocusNode();
  final _usernameFocus = FocusNode();

  late FocusScopeNode _focusScope;
  late S _s;

  final _srvs = locator<ServerProvider>();
  final _keys = locator<PrivateKeyProvider>();

  final _keyIdx = ValueNotifier<int?>(null);
  final _autoConnect = ValueNotifier(true);

  var _tags = <String>[];

  @override
  void initState() {
    super.initState();

    if (widget.spi != null) {
      _nameController.text = widget.spi?.name ?? '';
      _ipController.text = widget.spi?.ip ?? '';
      _portController.text = (widget.spi?.port ?? 22).toString();
      _usernameController.text = widget.spi?.user ?? '';
      if (widget.spi?.pubKeyId == null) {
        _passwordController.text = widget.spi?.pwd ?? '';
      } else {
        _keyIdx.value = _keys.pkis.indexWhere(
          (e) => e.id == widget.spi!.pubKeyId,
        );
      }
      if (widget.spi?.tags != null) {
        /// List in dart is passed by pointer, so you need to copy it here
        _tags.addAll(widget.spi!.tags!);
      }
      if (widget.spi?.alterUrl != null) {
        _altUrlController.text = widget.spi!.alterUrl!;
      }
      if (widget.spi?.autoConnect != null) {
        _autoConnect.value = widget.spi!.autoConnect!;
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _ipController.dispose();
    _altUrlController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _ipFocus.dispose();
    _alterUrlFocus.dispose();
    _portFocus.dispose();
    _usernameFocus.dispose();
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
                _srvs.delServer(widget.spi!.id);
                context.pop();
                context.pop(true);
              },
              child: Text(_s.ok, style: textRed),
            ),
          ],
        );
      },
      icon: const Icon(Icons.delete),
    );
    final actions = widget.spi != null ? [delBtn] : null;
    return CustomAppBar(
      title: Text(_s.edit, style: textSize18),
      actions: actions,
    );
  }

  Widget _buildForm() {
    final children = [
      Input(
        autoFocus: true,
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
        icon: Icons.computer,
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
        onSubmitted: (_) => _focusScope.requestFocus(_alterUrlFocus),
        label: _s.user,
        icon: Icons.account_box,
        hint: 'root',
      ),
      Input(
        controller: _altUrlController,
        type: TextInputType.text,
        node: _alterUrlFocus,
        label: _s.alterUrl,
        icon: Icons.computer,
        hint: 'user@ip:port',
      ),
      TagEditor(
        tags: _tags,
        onChanged: (p0) => _tags = p0,
        s: _s,
        allTags: [..._srvs.tags],
        onRenameTag: _srvs.renameTag,
      ),
      _buildAuth(),
      ListTile(
        title: Text(_s.autoConnect),
        trailing: ValueBuilder(
          listenable: _autoConnect,
          build: () => Switch(
            value: _autoConnect.value,
            onChanged: (val) {
              _autoConnect.value = val;
            },
          ),
        ),
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 47),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildAuth() {
    final switch_ = ListTile(
      title: Text(_s.keyAuth),
      trailing: ValueBuilder(
        listenable: _keyIdx,
        build: () => Switch(
          value: _keyIdx.value != null,
          onChanged: (val) {
            if (val) {
              _keyIdx.value = -1;
            } else {
              _keyIdx.value = null;
            }
          },
        ),
      ),
    );

    /// Put [switch_] out of [ValueBuilder] to avoid rebuild
    return ValueBuilder(
      listenable: _keyIdx,
      build: () {
        final children = <Widget>[switch_];
        if (_keyIdx.value != null) {
          children.add(_buildKeyAuth());
        } else {
          children.add(Input(
            controller: _passwordController,
            obscureText: true,
            type: TextInputType.text,
            label: _s.pwd,
            icon: Icons.password,
            hint: _s.pwd,
            onSubmitted: (_) => _onSave(),
          ));
        }
        return Column(children: children);
      },
    );
  }

  Widget _buildKeyAuth() {
    return Consumer<PrivateKeyProvider>(
      builder: (_, key, __) {
        final tiles = List<Widget>.generate(key.pkis.length, (index) {
          final e = key.pkis[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(
              '#${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            title: Text(e.id, textAlign: TextAlign.start),
            subtitle: Text(
              e.type ?? _s.unknown,
              textAlign: TextAlign.start,
              style: grey,
            ),
            trailing: _buildRadio(index, e),
          );
        });
        tiles.add(
          ListTile(
            title: Text(_s.addPrivateKey),
            contentPadding: EdgeInsets.zero,
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => AppRoute.keyEdit().go(context),
            ),
          ),
        );
        return RoundRectCard(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Column(
              children: tiles,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'server',
      onPressed: _onSave,
      child: const Icon(Icons.save),
    );
  }

  Widget _buildRadio(int index, PrivateKeyInfo pki) {
    return ValueBuilder(
      listenable: _keyIdx,
      build: () => Radio<int>(
        value: index,
        groupValue: _keyIdx.value,
        onChanged: (value) {
          _keyIdx.value = value;
        },
      ),
    );
  }

  void _onSave() async {
    if (_ipController.text == '') {
      showSnackBar(context, Text(_s.plzEnterHost));
      return;
    }
    if (_keyIdx.value == null && _passwordController.text == '') {
      final cancel = await showRoundDialog<bool>(
        context: context,
        title: Text(_s.attention),
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
    // If [_pubKeyIndex] is -1, it means that the user has not selected
    if (_keyIdx.value == -1) {
      showSnackBar(context, Text(_s.plzSelectKey));
      return;
    }
    if (_usernameController.text.isEmpty) {
      _usernameController.text = 'root';
    }
    if (_portController.text.isEmpty) {
      _portController.text = '22';
    }

    final spi = ServerPrivateInfo(
      name: _nameController.text,
      ip: _ipController.text,
      port: int.parse(_portController.text),
      user: _usernameController.text,
      pwd: _passwordController.text.isEmpty ? null : _passwordController.text,
      pubKeyId: _keyIdx.value != null
          ? _keys.pkis.elementAt(_keyIdx.value!).id
          : null,
      tags: _tags,
      alterUrl: _altUrlController.text.isEmpty ? null : _altUrlController.text,
      autoConnect: _autoConnect.value,
    );

    if (widget.spi == null) {
      _srvs.addServer(spi);
    } else {
      _srvs.updateServer(widget.spi!, spi);
    }

    context.pop();
  }
}
