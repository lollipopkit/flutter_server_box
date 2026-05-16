import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/res/misc.dart';

const _format = 'text/plain';
final _whitespaceRegex = RegExp(r'\s+');
final _pemBeginRegex = RegExp(r'^-----BEGIN ([A-Z0-9 ]+)-----$');
final _pemEndRegex = RegExp(r'^-----END ([A-Z0-9 ]+)-----$');

final class PrivateKeyEditPageArgs {
  final PrivateKeyInfo? pki;
  const PrivateKeyEditPageArgs({this.pki});
}

class PrivateKeyEditPage extends ConsumerStatefulWidget {
  final PrivateKeyEditPageArgs? args;
  const PrivateKeyEditPage({super.key, this.args});

  @override
  ConsumerState<PrivateKeyEditPage> createState() => _PrivateKeyEditPageState();

  static const route = AppRoute(
    page: PrivateKeyEditPage.new,
    path: '/private_key/edit',
  );
}

class _PrivateKeyEditPageState extends ConsumerState<PrivateKeyEditPage> {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _pwdController = TextEditingController();
  final _nameNode = FocusNode();
  final _keyNode = FocusNode();
  final _pwdNode = FocusNode();

  late FocusScopeNode _focusScope;

  final _loading = ValueNotifier<Widget?>(null);

  late final _notifier = ref.read(privateKeyProvider.notifier);

  PrivateKeyInfo? get pki => widget.args?.pki;

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
    final pki = this.pki;
    if (pki != null) {
      _nameController.text = pki.id;
      _keyController.text = pki.key;
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

  CustomAppBar _buildAppBar() {
    final pki = this.pki;
    final actions = pki != null
        ? [
            IconButton(
              tooltip: libL10n.delete,
              onPressed: () {
                context.showRoundDialog(
                  title: libL10n.attention,
                  child: Text(
                    libL10n.askContinue(
                      '${libL10n.delete} ${l10n.privateKey}(${pki.id})',
                    ),
                  ),
                  actions: Btn.ok(
                    onTap: () {
                      _notifier.delete(pki);
                      context.pop();
                      context.pop();
                    },
                    red: true,
                  ).toList,
                );
              },
              icon: const Icon(Icons.delete),
            ),
          ]
        : null;
    return CustomAppBar(title: Text(libL10n.edit), actions: actions);
  }

  String _standardizeLineSeparators(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Normalizes the private key format:
  /// - Removes whitespace from Base64 content (spaces, tabs, etc.)
  /// - Ensures the key ends with a newline
  String _normalizePrivateKey(String key) {
    final lines = key.split('\n');
    // Guard: need at least header + body + footer (3 lines) for valid PEM
    if (lines.length < 3) return key;

    final header = lines.first;
    final footer = lines.last;

    // Validate PEM boundaries before mutating input
    final headerMatch = _pemBeginRegex.firstMatch(header);
    final footerMatch = _pemEndRegex.firstMatch(footer);
    if (headerMatch == null || footerMatch == null) {
      return key;
    }

    // Ensure header and footer labels match
    final headerLabel = headerMatch.group(1);
    final footerLabel = footerMatch.group(1);
    if (headerLabel != footerLabel) {
      return key;
    }

    // Extract Base64 content (everything between header and footer)
    final bodyLines = lines.sublist(1, lines.length - 1);

    // Check for RFC 1421 metadata headers (e.g., Proc-Type, DEK-Info)
    // These appear in encrypted PEM keys and must be preserved
    final hasMetadataHeaders = bodyLines.any(
      (line) => line.contains(':') && !line.startsWith('-----'),
    );

    if (hasMetadataHeaders) {
      // For encrypted keys, preserve structure and just ensure trailing newline
      if (!key.endsWith('\n')) {
        return '$key\n';
      }
      return key;
    }

    // Remove all whitespace from Base64 content
    final cleanBody = bodyLines.join('').replaceAll(_whitespaceRegex, '');

    // Rebuild the key with standard formatting (64 chars per line)
    final buffer = StringBuffer();
    buffer.writeln(header);
    for (var i = 0; i < cleanBody.length; i += 64) {
      final end = (i + 64 < cleanBody.length) ? i + 64 : cleanBody.length;
      buffer.writeln(cleanBody.substring(i, end));
    }
    buffer.writeln(footer);

    return buffer.toString();
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      tooltip: l10n.save,
      onPressed: _onTapSave,
      child: const Icon(Icons.save),
    );
  }

  Widget _buildBody() {
    return AutoMultiList(
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
          label: libL10n.pwd,
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
    final key = _normalizePrivateKey(
      _standardizeLineSeparators(_keyController.text.trim()),
    );
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
      final originPki = this.pki;
      if (originPki != null) {
        _notifier.update(originPki, pki);
      } else {
        _notifier.add(pki);
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
