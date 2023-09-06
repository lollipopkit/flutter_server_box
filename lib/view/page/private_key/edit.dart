import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context.dart';
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
import '../../widget/custom_appbar.dart';

const _format = 'text/plain';

class PrivateKeyEditPage extends StatefulWidget {
  const PrivateKeyEditPage({Key? key, this.pki}) : super(key: key);

  final PrivateKeyInfo? pki;

  @override
  _PrivateKeyEditPageState createState() => _PrivateKeyEditPageState();
}

class _PrivateKeyEditPageState extends State<PrivateKeyEditPage> {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _pwdController = TextEditingController();
  final _nameNode = FocusNode();
  final _keyNode = FocusNode();
  final _pwdNode = FocusNode();

  late FocusScopeNode _focusScope;
  final _provider = locator<PrivateKeyProvider>();
  late S _s;

  Widget? _loading;

  @override
  void initState() {
    super.initState();
    if (widget.pki != null) {
      _nameController.text = widget.pki!.id;
      _keyController.text = widget.pki!.key;
    } else {
      Clipboard.getData(_format).then((value) {
        if (value == null) return;
        final clipdata = value.text?.trim() ?? '';
        if (clipdata.startsWith('-----BEGIN') && clipdata.endsWith('-----')) {
          _keyController.text = clipdata;
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _keyController.dispose();
    _pwdController.dispose();
    _nameNode.dispose();
    _keyNode.dispose();
    _pwdNode.dispose();
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
    final actions = [
      IconButton(
        tooltip: _s.delete,
        onPressed: () {
          showRoundDialog(
            context: context,
            title: Text(_s.attention),
            child: Text(_s.sureDelete(widget.pki!.id)),
            actions: [
              TextButton(
                onPressed: () {
                  _provider.delete(widget.pki!);
                  context.pop();
                  context.pop();
                },
                child: Text(
                  _s.ok,
                  style: textRed,
                ),
              ),
            ],
          );
        },
        icon: const Icon(Icons.delete),
      )
    ];
    return CustomAppBar(
      title: Text(_s.edit, style: textSize18),
      actions: widget.pki == null ? null : actions,
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
        try {
          final decrypted = await compute(decyptPem, [key, pwd]);
          final pki = PrivateKeyInfo(id: name, key: decrypted);
          if (widget.pki != null) {
            _provider.update(widget.pki!, pki);
          } else {
            _provider.add(pki);
          }
        } catch (e) {
          showSnackBar(context, Text(e.toString()));
          rethrow;
        } finally {
          setState(() {
            _loading = null;
          });
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
          autoFocus: true,
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
        _loading ?? placeholder,
      ],
    );
  }
}
