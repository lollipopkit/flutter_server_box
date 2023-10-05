import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/view/widget/input_field.dart';

import '../../../core/utils/server.dart';
import '../../../data/model/server/private_key_info.dart';
import '../../../data/res/ui.dart';
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
        tooltip: l10n.delete,
        onPressed: () {
          context.showRoundDialog(
            title: Text(l10n.attention),
            child: Text(l10n.askContinue(
              '${l10n.delete} ${l10n.privateKey}(${widget.pki!.id})',
            )),
            actions: [
              TextButton(
                onPressed: () {
                  Pros.key.delete(widget.pki!);
                  context.pop();
                  context.pop();
                },
                child: Text(
                  l10n.ok,
                  style: UIs.textRed,
                ),
              ),
            ],
          );
        },
        icon: const Icon(Icons.delete),
      )
    ];
    return CustomAppBar(
      title: Text(l10n.edit, style: UIs.textSize18),
      actions: widget.pki == null ? null : actions,
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      tooltip: l10n.save,
      onPressed: () async {
        final name = _nameController.text;
        final key = _keyController.text.trim();
        final pwd = _pwdController.text;
        if (name.isEmpty || key.isEmpty) {
          context.showSnackBar(l10n.fieldMustNotEmpty);
          return;
        }
        FocusScope.of(context).unfocus();
        setState(() {
          _loading = UIs.centerSizedLoading;
        });
        try {
          final decrypted = await compute(decyptPem, [key, pwd]);
          final pki = PrivateKeyInfo(id: name, key: decrypted);
          if (widget.pki != null) {
            Pros.key.update(widget.pki!, pki);
          } else {
            Pros.key.add(pki);
          }
        } catch (e) {
          context.showSnackBar(e.toString());
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
          label: l10n.name,
          icon: Icons.info,
        ),
        Input(
          controller: _keyController,
          minLines: 3,
          maxLines: 10,
          type: TextInputType.text,
          node: _keyNode,
          onSubmitted: (_) => _focusScope.requestFocus(_pwdNode),
          label: l10n.privateKey,
          icon: Icons.vpn_key,
        ),
        TextButton(
          onPressed: () async {
            final path = await pickOneFile();
            if (path == null) {
              context.showSnackBar(l10n.fieldMustNotEmpty);
              return;
            }

            final file = File(path);
            if (!file.existsSync()) {
              context.showSnackBar(l10n.fileNotExist(path));
              return;
            }
            final size = (await file.stat()).size;
            if (size > Miscs.privateKeyMaxSize) {
              context.showSnackBar(
                l10n.fileTooLarge(
                  path,
                  size.convertBytes,
                  Miscs.privateKeyMaxSize.convertBytes,
                ),
              );
              return;
            }

            _keyController.text = await file.readAsString();
          },
          child: Text(l10n.pickFile),
        ),
        Input(
          controller: _pwdController,
          type: TextInputType.text,
          node: _pwdNode,
          obscureText: true,
          label: l10n.pwd,
          icon: Icons.password,
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        _loading ?? UIs.placeholder,
      ],
    );
  }
}
