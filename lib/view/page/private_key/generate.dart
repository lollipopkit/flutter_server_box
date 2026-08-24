import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/ssh_keygen.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/store/entity_store.dart';

/// Making a key pair here rather than somewhere else and importing it.
///
/// Two halves, one after the other on the same page: what to make, and then
/// the public key to put on the server. The second half is why this is a page
/// and not a dialog that saves and closes — the public key is the whole point
/// of having generated one, and a screen that vanished on save would leave the
/// person with a key they cannot use yet.
class PrivateKeyGeneratePage extends ConsumerStatefulWidget {
  const PrivateKeyGeneratePage({super.key});

  @override
  ConsumerState<PrivateKeyGeneratePage> createState() =>
      _PrivateKeyGeneratePageState();

  static const route = AppRouteNoArg(
    page: PrivateKeyGeneratePage.new,
    path: '/private_key/generate',
  );
}

class _PrivateKeyGeneratePageState
    extends ConsumerState<PrivateKeyGeneratePage> {
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  final _pwdController = TextEditingController();

  /// Closes the algorithm list once a choice has been made.
  final _algorithmTile = ExpansibleController();

  var _algorithm = SshKeyAlgorithm.ed25519;
  var _working = false;

  /// The line to put on the server, once there is one. Its presence is what
  /// decides which half of the page is showing.
  String? _publicLine;

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _pwdController.dispose();
    _algorithmTile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.sshKeyGenerate)),
      body: _publicLine == null ? _buildForm() : _buildResult(),
      floatingActionButton: _publicLine == null
          ? FloatingActionButton(
              tooltip: l10n.sshKeyGenerate,
              onPressed: _working ? null : _onGenerate,
              child: _working
                  ? SizedLoading.small
                  : const Icon(Icons.vpn_key),
            )
          : null,
    );
  }

  Widget _buildForm() {
    return PageColumns(
      children: [
        Input(
          autoFocus: true,
          controller: _nameController,
          type: TextInputType.text,
          label: libL10n.name,
          icon: Icons.info,
          suggestion: true,
        ),
        // Closed to begin with, showing what it is set to. There is a right
        // answer here for almost everyone and it is the default; opening this
        // is for the case where a server refuses it, not something to read on
        // the way past.
        ExpansionTile(
          controller: _algorithmTile,
          leading: const Icon(Icons.key),
          title: Text(l10n.sshKeyAlgorithm),
          subtitle: Text(_algorithmLabel(_algorithm), style: UIs.textGrey),
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          children: [
            RadioGroup<SshKeyAlgorithm>(
              groupValue: _algorithm,
              onChanged: (value) {
                // Guarded here rather than by a null `onChanged`: RadioGroup
                // takes a non-nullable callback, and disabling the tiles while
                // a key is being generated is what this is for.
                if (_working || value == null) return;
                setState(() => _algorithm = value);
                // The choice is made, so the list has done its job — leaving
                // it open would cover the rest of the form with four rows
                // nobody is reading any more.
                _algorithmTile.collapse();
              },
              child: Column(
                children: [
                  for (final algorithm in SshKeyAlgorithm.values)
                    RadioListTile<SshKeyAlgorithm>(
                      value: algorithm,
                      enabled: !_working,
                      title: Text(_algorithmLabel(algorithm)),
                      subtitle: Text(
                        _algorithmSubtitle(algorithm),
                        style: UIs.textGrey,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ).cardx,
        Input(
          controller: _commentController,
          type: TextInputType.text,
          label: l10n.sshKeyComment,
          icon: Icons.comment,
          hint: 'serverbox',
          suggestion: false,
        ),
        Input(
          controller: _pwdController,
          type: TextInputType.text,
          obscureText: true,
          label: libL10n.pwd,
          icon: Icons.password,
          suggestion: false,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(l10n.sshKeyPassphraseTip, style: UIs.textGrey),
        ),
        // RSA searches for primes and takes seconds on a phone. A spinning
        // button with nothing beside it reads as a button that did not work.
        if (_working)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(l10n.sshKeyGenerating, style: UIs.textGrey),
          ),
      ],
    );
  }

  Widget _buildResult() {
    return PageColumns(
      children: [
        ListTile(
          leading: const Icon(Icons.public),
          title: Text(l10n.sshKeyPublicKey),
          subtitle: Text(l10n.sshKeyPublicKeyTip, style: UIs.textGrey),
          trailing: IconButton(
            tooltip: libL10n.copy,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _publicLine!));
              Toast.success(libL10n.success);
            },
          ),
        ).cardx,
        Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            _publicLine!,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ).cardx,
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () => context.pop(),
            child: Text(libL10n.ok),
          ),
        ),
      ],
    );
  }

  String _algorithmLabel(SshKeyAlgorithm algorithm) => switch (algorithm) {
    SshKeyAlgorithm.ed25519 => 'Ed25519',
    SshKeyAlgorithm.ecdsaP256 => 'ECDSA (P-256)',
    SshKeyAlgorithm.rsa2048 => 'RSA 2048',
    SshKeyAlgorithm.rsa4096 => 'RSA 4096',
  };

  /// Why someone would pick this one. The identifiers stay as they are — they
  /// are what a server names in its config, not prose — while the line for the
  /// default is a sentence and is translated.
  String _algorithmSubtitle(SshKeyAlgorithm algorithm) => switch (algorithm) {
    SshKeyAlgorithm.ed25519 => l10n.sshKeyRecommended,
    SshKeyAlgorithm.ecdsaP256 => 'ecdsa-sha2-nistp256',
    SshKeyAlgorithm.rsa2048 || SshKeyAlgorithm.rsa4096 => 'ssh-rsa',
  };

  Future<void> _onGenerate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Toast.show(libL10n.empty);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _working = true);
    try {
      final typed = _commentController.text.trim();
      // The name is what the person will recognise it by, and an OpenSSH
      // comment with nothing in it tells whoever reads `authorized_keys` later
      // nothing about where the key came from.
      final comment = typed.isEmpty ? name : typed;
      final key = await generateSshKey(
        algorithm: _algorithm,
        comment: comment,
        passphrase: _pwdController.text.isEmpty ? null : _pwdController.text,
      );
      // RSA searches for primes and takes seconds, which is long enough to
      // leave. Saving after that would put a key in the list whose public half
      // was never shown — the half that has to reach the server for it to be
      // any use — so a page that has gone drops the key instead. Making
      // another costs only the wait.
      if (!mounted) return;
      await ref
          .read(privateKeyProvider.notifier)
          .add(
            PrivateKeyInfo(
              id: ShortId.generate(),
              name: name,
              key: key.privatePem,
              // Stored as well as written into the key. For a key with a
              // passphrase the copy inside it cannot be read back — it is in
              // the part that gets encrypted — so without this the list would
              // show no comment and the public key line offered later would
              // not be the one that was just copied.
              comment: comment,
            ),
          );
      if (!mounted) return;
      setState(() => _publicLine = key.publicLine);
    } on DuplicateNameException catch (e) {
      // The name is unique in the schema, so this is where a collision is
      // found. The page stays open on the name that has to change — and the
      // key that was generated is dropped, which costs nothing to make again.
      Toast.error(l10n.nameAlreadyExistsFmt(e.name));
    } catch (e) {
      Toast.error(e.toString());
      rethrow;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
