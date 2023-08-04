import 'dart:io';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:nil/nil.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/view/widget/input_field.dart';

import '../../../core/utils/server.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/server/private_key_info.dart';
import '../../../data/provider/private_key.dart';
import '../../../data/res/ui.dart';
import '../../../locator.dart';

const _format = 'text/plain';

class PrivateKeyEditPage extends StatefulWidget {
  const PrivateKeyEditPage({Key? key, this.info}) : super(key: key);

  final PrivateKeyInfo? info;

  @override
  _PrivateKeyEditPageState createState() => _PrivateKeyEditPageState();
}

class _PrivateKeyEditPageState extends State<PrivateKeyEditPage>
    with AfterLayoutMixin {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _pwdController = TextEditingController();
  final _nameNode = FocusNode();
  final _keyNode = FocusNode();
  final _pwdNode = FocusNode();

  late FocusScopeNode _focusScope;
  late PrivateKeyProvider _provider;
  late S _s;

  Widget _loading = nil;

  @override
  void initState() {
    super.initState();
    _provider = locator<PrivateKeyProvider>();
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
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final actions = widget.info == null
        ? null
        : [
            IconButton(
                tooltip: _s.delete,
                onPressed: () {
                  _provider.delete(widget.info!);
                  context.pop();
                },
                icon: const Icon(Icons.delete))
          ];
    return AppBar(
      title: Text(_s.edit, style: textSize18),
      actions: actions,
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      tooltip: _s.save,
      onPressed: () async {
        final name = _nameController.text;
        final key = _keyController.text.trim();
        final pwd = _pwdController.text;
        if (name.isEmpty || key.isEmpty) {
          showSnackBar(context, Text(_s.fieldMustNotEmpty));
          return;
        }
        FocusScope.of(context).unfocus();
        setState(() {
          _loading = centerSizedLoading;
        });
        final info = PrivateKeyInfo(id: name, key: key);
        try {
          info.key = await compute(decyptPem, [key, pwd]);
        } catch (e) {
          showSnackBar(context, Text(e.toString()));
          rethrow;
        } finally {
          setState(() {
            _loading = nil;
          });
        }
        if (widget.info != null) {
          _provider.update(widget.info!, info);
        } else {
          _provider.add(info);
        }
        context.pop();
      },
      child: const Icon(Icons.save),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(13),
      children: [
        Input(
          controller: _nameController,
          type: TextInputType.text,
          node: _nameNode,
          onSubmitted: (_) => _focusScope.requestFocus(_keyNode),
          label: _s.name,
          icon: Icons.info,
        ),
        Input(
          controller: _keyController,
          minLines: 3,
          maxLines: 10,
          type: TextInputType.text,
          node: _keyNode,
          onSubmitted: (_) => _focusScope.requestFocus(_pwdNode),
          label: _s.privateKey,
          icon: Icons.vpn_key,
        ),
        TextButton(
          onPressed: () async {
            final path = await pickOneFile();
            if (path == null) {
              showSnackBar(context, Text(_s.fieldMustNotEmpty));
              return;
            }

            final file = File(path);
            if (!file.existsSync()) {
              showSnackBar(context, Text(_s.fileNotExist(path)));
              return;
            }
            final size = (await file.stat()).size;
            if (size > privateKeyMaxSize) {
              showSnackBar(
                context,
                Text(
                  _s.fileTooLarge(
                    path,
                    size.convertBytes,
                    privateKeyMaxSize.convertBytes,
                  ),
                ),
              );
              return;
            }

            _keyController.text = await file.readAsString();
          },
          child: Text(_s.pickFile),
        ),
        Input(
          controller: _pwdController,
          type: TextInputType.text,
          node: _pwdNode,
          obscureText: true,
          label: _s.pwd,
          icon: Icons.password,
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        _loading
      ],
    );
  }

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    if (widget.info != null) {
      _nameController.text = widget.info!.id;
      _keyController.text = widget.info!.key;
    } else {
      final clipdata = ((await Clipboard.getData(_format))?.text ?? '').trim();
      if (clipdata.startsWith('-----BEGIN') && clipdata.endsWith('-----')) {
        _keyController.text = clipdata;
      }
    }
  }
}
