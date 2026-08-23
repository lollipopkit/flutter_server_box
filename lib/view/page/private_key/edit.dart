import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_key_unlock.dart';
import 'package:server_box/core/utils/ssh_keygen.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/entity_store.dart';

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
  final _commentController = TextEditingController();
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
    _commentController.dispose();
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
      _nameController.text = pki.name;
      _keyController.text = pki.key;
      // The stored one if the label has been edited, otherwise whatever the
      // key arrived with — which is absent for an encrypted key, since the
      // key's own comment is inside the part that gets encrypted.
      _commentController.text =
          pki.comment ?? describeSshKey(pki.key).comment ?? '';
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
              tooltip: l10n.sshKeyPublicKey,
              onPressed: () => _showPublicKey(pki),
              icon: const Icon(Icons.public),
            ),
            IconButton(
              tooltip: libL10n.delete,
              onPressed: () async {
                // The dialog answers; the page acts on the answer. See the
                // snippet editor for why not from inside the button.
                final confirmed = await context.showRoundDialog<bool>(
                  title: libL10n.attention,
                  child: Text(
                    libL10n.askContinue(
                      '${libL10n.delete} ${l10n.privateKey}(${pki.name})',
                    ),
                  ),
                  actions: Btn.ok(red: true).toList,
                );
                if (confirmed != true || !context.mounted) return;
                PrivateKeyUnlock.forget(pki.id);
                await _notifier.delete(pki);
                context.pop();
              },
              icon: const Icon(Icons.delete),
            ),
          ]
        : null;
    return CustomAppBar(title: Text(libL10n.edit), actions: actions);
  }

  /// Derives the public half and offers it for copying.
  ///
  /// Derived rather than stored: only the private key is kept, and the public
  /// key is a function of it. For an encrypted key this is the same unlock a
  /// connection does, so it asks once and both paths share the answer.
  Future<void> _showPublicKey(PrivateKeyInfo pki) async {
    String line;
    try {
      final opened = await PrivateKeyUnlock.open(
        pki.key,
        cacheKey: pki.id,
        keyName: pki.name,
      );
      line = publicKeyLine(
        SSHKeyPair.fromPem(opened).first,
        // Read from `opened`, not from the stored bytes: for an encrypted key
        // the comment is inside the part that was just decrypted, and asking
        // the locked form yields nothing.
        pki.comment ?? describeSshKey(opened).comment ?? pki.name,
      );
    } catch (e) {
      Toast.error(e.toString());
      return;
    }
    if (!mounted) return;
    await context.showRoundDialog(
      title: l10n.sshKeyPublicKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sshKeyPublicKeyTip, style: UIs.textGrey),
          const SizedBox(height: 12),
          SelectableText(
            line,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: line));
            Toast.success(libL10n.success);
          },
          child: Text(libL10n.copy),
        ),
        TextButton(onPressed: context.popDialog, child: Text(libL10n.ok)),
      ],
    );
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
      tooltip: libL10n.save,
      onPressed: _onTapSave,
      child: const Icon(Icons.save),
    );
  }

  Widget _buildBody() {
    return PageColumns(
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
                Toast.show(libL10n.notExistFmt(path));
                return;
              }
              final size = (await file.stat()).size;
              if (size > Miscs.privateKeyMaxSize) {
                Toast.show(
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
          ),
          Input(
            controller: _commentController,
            type: TextInputType.text,
            label: l10n.sshKeyComment,
            icon: Icons.comment,
            suggestion: false,
            onSubmitted: (_) => _onTapSave(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(l10n.sshKeyPublicKeyTip, style: UIs.textGrey),
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
      Toast.show(libL10n.empty);
      return;
    }
    FocusScope.of(context).unfocus();
    _loading.value = SizedLoading.medium;
    try {
      // Stored as it was given. An encrypted key stays encrypted — the
      // passphrase is what protects it, and stripping it here left every
      // imported key lying in the database in the clear.
      //
      // Parsed either way, which is what rejects a key that is not one. The
      // old code got that for free from always decrypting; guarding the call
      // on "is it encrypted" lost it, because `isLocked` answers false for
      // anything it cannot read rather than throwing.
      //
      // A passphrase typed alongside it is checked rather than applied: a typo
      // found now says so on this page, where it can be fixed, instead of at
      // the next connection as a key that will not open.
      //
      // `compute`, not `Computer.shared`, for the same reason the unlocker
      // uses it: one that has to be turned on cannot be called from a test.
      final opened = await compute(decryptPem, [key, pwd]);
      // The id of the record being edited: renaming a key must not detach the
      // servers pointing at it, which is what happened when the two were one
      // value.
      final comment = _commentController.text.trim();
      final pki = PrivateKeyInfo(
        id: this.pki?.id ?? ShortId.generate(),
        name: name,
        key: key,
        // Null rather than empty, so an untouched field goes on meaning
        // "whatever the key itself says" instead of "no comment".
        comment: comment.isEmpty ? null : comment,
      );
      // The bytes may have changed under an id that has not, so whatever was
      // opened for it no longer describes what is stored — and then the
      // passphrase just verified is put back, rather than asking for it again
      // seconds later on the first connection.
      PrivateKeyUnlock.forget(pki.id);
      if (pwd.isNotEmpty && opened != key) {
        PrivateKeyUnlock.remember(pki.id, opened);
      }
      final originPki = this.pki;
      if (originPki != null) {
        await _notifier.update(originPki, pki);
      } else {
        await _notifier.add(pki);
      }
    } on DuplicateNameException catch (e) {
      // The name is unique in the schema, so this is where a collision is
      // found. The page stays open on the name the user has to change.
      Toast.error(l10n.nameAlreadyExistsFmt(e.name));
      return;
    } catch (e) {
      Toast.error(e.toString());
      rethrow;
    } finally {
      // `decryptPem` runs on another isolate, so the page can be gone by the
      // time this runs — and `_loading` is disposed with it.
      if (mounted) _loading.value = null;
    }
    if (!mounted) return;
    context.pop();
  }
}
