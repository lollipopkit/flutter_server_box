import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/data/store/entity_store.dart';

final class BmcCredentialEditPageArgs {
  /// The account being edited, or null to create one.
  final BmcCredential? cred;

  const BmcCredentialEditPageArgs({this.cred});
}

/// One BMC account.
///
/// A page rather than a dialog because it is reached from two places — the
/// account list, and the picker on the server editor — and a dialog owned by
/// one of them would have to be duplicated by the other. The private key pages
/// are the same arrangement for the same reason.
class BmcCredentialEditPage extends ConsumerStatefulWidget {
  final BmcCredentialEditPageArgs? args;

  const BmcCredentialEditPage({super.key, this.args});

  @override
  ConsumerState<BmcCredentialEditPage> createState() =>
      _BmcCredentialEditPageState();

  static const route = AppRoute(
    page: BmcCredentialEditPage.new,
    path: '/bmc_credential/edit',
  );
}

class _BmcCredentialEditPageState extends ConsumerState<BmcCredentialEditPage> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  late final _notifier = ref.read(bmcCredentialProvider.notifier);

  BmcCredential? get cred => widget.args?.cred;

  @override
  void initState() {
    super.initState();
    final existing = cred;
    if (existing == null) return;
    _nameCtrl.text = existing.name;
    _userCtrl.text = existing.user;
    _pwdCtrl.text = existing.pwd ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = cred;
    final shared = existing == null ? 0 : _notifier.serversUsing(existing.id);

    return Scaffold(
      appBar: CustomAppBar(
        title: Text(existing == null ? libL10n.add : l10n.bmcAccount),
        actions: [
          if (existing != null)
            IconButton(
              onPressed: () => _onDelete(existing, shared),
              icon: const Icon(Icons.delete),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          children: [
            // Said before the fields rather than after them: it is a reason
            // someone might not want to edit this record at all, and the
            // twenty servers it would change are not otherwise visible here.
            if (shared > 1)
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(l10n.bmcAccountShared(shared)),
                subtitle: Text(l10n.bmcAccountSharedTip, style: UIs.textGrey),
              ).cardx,
            Input(
              controller: _nameCtrl,
              label: libL10n.name,
              icon: Icons.label_outline,
              hint: 'rack-a',
              suggestion: false,
              autoFocus: existing == null,
            ),
            Input(
              controller: _userCtrl,
              label: libL10n.user,
              icon: Icons.person,
              hint: 'ADMIN',
              suggestion: false,
            ),
            Input(
              controller: _pwdCtrl,
              label: libL10n.pwd,
              icon: Icons.password,
              obscureText: true,
              suggestion: false,
              onSubmitted: (_) => _onSave(),
            ),
            const SizedBox(height: 17),
            Btn.tile(
              text: libL10n.save,
              icon: const Icon(Icons.save),
              onTap: _onSave,
            ),
          ],
        ),
      ),
    );
  }
}

extension on _BmcCredentialEditPageState {
  Future<void> _onSave() async {
    final name = _nameCtrl.text.trim();
    final user = _userCtrl.text.trim();
    if (name.isEmpty || user.isEmpty) {
      Toast.error(libL10n.fail, body: libL10n.empty);
      return;
    }
    final pwd = _pwdCtrl.text.selfNotEmptyOrNull;

    final existing = cred;
    final saved =
        existing?.copyWith(name: name, user: user, pwd: pwd) ??
        BmcCredential(
          id: ShortId.generate(),
          name: name,
          user: user,
          pwd: pwd,
        );

    try {
      if (existing == null) {
        await _notifier.add(saved);
      } else {
        await _notifier.update(existing, saved);
      }
    } on DuplicateNameException catch (e) {
      // The name is `UNIQUE` in the schema, so the collision is found here
      // rather than in whichever dialog last remembered to check for it. The
      // page stays open on the name the user has to change.
      Toast.error(l10n.nameAlreadyExistsFmt(e.name));
      return;
    } catch (e) {
      Toast.error(libL10n.fail, body: '$e');
      return;
    }
    if (mounted) context.pop(saved);
  }

  Future<void> _onDelete(BmcCredential existing, int shared) async {
    final sure = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        shared > 0
            ? '${libL10n.askContinue(libL10n.delete)}\n\n'
                  '${l10n.bmcAccountInUse(shared)}'
            : libL10n.askContinue('${libL10n.delete}(${existing.name})'),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (sure != true) return;

    await _notifier.delete(existing);
    // The page is closed by the code that awaited the dialog, on the page's own
    // navigator — see the dialog rules in CLAUDE.md.
    if (mounted) context.pop();
  }
}
