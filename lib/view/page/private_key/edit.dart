import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/res/misc.dart';

import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/private_key_info.dart';

const _format = 'text/plain';

class PrivateKeyEditPage extends StatefulWidget {
  const PrivateKeyEditPage({super.key, this.pki});

  final PrivateKeyInfo? pki;

  @override
  State<PrivateKeyEditPage> createState() => _PrivateKeyEditPageState();
}

class _PrivateKeyEditPageState extends State<PrivateKeyEditPage> {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _pwdController = TextEditingController();
  final _nameNode = FocusNode();
  final _keyNode = FocusNode();
  final _pwdNode = FocusNode();

  late FocusScopeNode _focusScope;

  final _loading = ValueNotifier<Widget?>(null);

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _keyController.dispose();
    _pwdController.dispose();
    _nameNode.dispose();
    _keyNode.dispose();
    _pwdNode.dispose();
    _loading.dispose();
  }

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

  AppBar _buildAppBar() {
    final actions = [
      IconButton(
        tooltip: libL10n.delete,
        onPressed: () {
          context.showRoundDialog(
            title: libL10n.attention,
            child: Text(libL10n.askContinue(
              '${libL10n.delete} ${l10n.privateKey}(${widget.pki!.id})',
            )),
            actions: Btn.ok(
              onTap: () {
                PrivateKeyProvider.delete(widget.pki!);
                context.pop();
                context.pop();
              },
              red: true,
            ).toList,
          );
        },
        icon: const Icon(Icons.delete),
      )
    ];
    return AppBar(
      title: Text(libL10n.edit),
      actions: widget.pki == null ? null : actions,
    );
  }

  String _standardizeLineSeparators(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      tooltip: l10n.save,
      onPressed: _onTapSave,
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
          label: libL10n.name,
          icon: Icons.info,
          suggestion: true,
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
          suggestion: false,
        ),
        TextButton(
          onPressed: () async {
            final path = await Pfs.pickFilePath();
            if (path == null) return;

            final file = File(path);
            if (!file.existsSync()) {
              context.showSnackBar(libL10n.notExistFmt(path));
              return;
            }
            final size = (await file.stat()).size;
            if (size > Miscs.privateKeyMaxSize) {
              context.showSnackBar(
                l10n.fileTooLarge(
                  path,
                  size.bytes2Str,
                  Miscs.privateKeyMaxSize.bytes2Str,
                ),
              );
              return;
            }

            final content = await file.readAsString();
            // dartssh2 accepts only LF (but not CRLF or CR)
            _keyController.text = _standardizeLineSeparators(content.trim());
          },
          child: Text(libL10n.file),
        ),
        Input(
          controller: _pwdController,
          type: TextInputType.text,
          node: _pwdNode,
          obscureText: true,
          label: l10n.pwd,
          icon: Icons.password,
          suggestion: false,
          onSubmitted: (_) => _onTapSave(),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        ValBuilder(
          listenable: _loading,
          builder: (val) => val ?? UIs.placeholder,
        ),
      ],
    );
  }

  void _onTapSave() async {
    final name = _nameController.text;
    final key = _standardizeLineSeparators(_keyController.text.trim());
    final pwd = _pwdController.text;
    if (name.isEmpty || key.isEmpty) {
      context.showSnackBar(libL10n.empty);
      return;
    }
    FocusScope.of(context).unfocus();
    _loading.value = SizedLoading.medium;
    try {
      final decrypted = await Computer.shared.start(decyptPem, [key, pwd]);
      final pki = PrivateKeyInfo(id: name, key: decrypted);
      final originPki = widget.pki;
      if (originPki != null) {
        PrivateKeyProvider.update(originPki, pki);
      } else {
        PrivateKeyProvider.add(pki);
      }
    } catch (e) {
      context.showSnackBar(e.toString());
      rethrow;
    } finally {
      _loading.value = null;
    }
    context.pop();
  }
}
