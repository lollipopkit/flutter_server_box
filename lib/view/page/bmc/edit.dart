import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/bmc/bmc_cfg.dart';
import 'package:server_box/data/model/bmc/bmc_credential.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc_credential.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/view/page/bmc/common.dart';
import 'package:server_box/view/page/bmc/credential/edit.dart';
import 'package:server_box/view/widget/marked_title.dart';
import 'package:server_box/view/widget/server_picker.dart';

/// Editor for a standalone or server-linked [BmcTarget].
final class BmcTargetEditPage extends ConsumerStatefulWidget {
  final BmcTargetEditArgs? args;

  const BmcTargetEditPage({super.key, this.args});

  static const route = AppRoute<BmcTarget?, BmcTargetEditArgs>(
    page: BmcTargetEditPage.new,
    path: '/bmc/edit',
  );

  @override
  ConsumerState<BmcTargetEditPage> createState() => _BmcTargetEditPageState();
}

final class _BmcTargetEditPageState extends ConsumerState<BmcTargetEditPage> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _tags = ValueNotifier<Set<String>>({});

  String? _credId;
  String? _certSha256;

  /// The trimmed URL [_certSha256] was pinned against. Changing the address
  /// clears the pin so the new host's certificate is reviewed rather than
  /// rejected as a changed certificate.
  String? _certAddr;
  String? _serverId;

  BmcTarget? get _existing => widget.args?.target;

  String? get _effectiveCertSha256 =>
      _certAddr == _addrCtrl.text.trim() ? _certSha256 : null;

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _addrCtrl.text = existing.addr;
      _credId = existing.credId;
      _certSha256 = existing.certSha256;
      _certAddr = existing.certSha256 != null ? existing.addr.trim() : null;
      _serverId = existing.serverId;
      _tags.value = Set<String>.from(existing.tags ?? const []);
    } else {
      _serverId = widget.args?.serverId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creds = ref.watch(bmcCredentialProvider).creds;
    final servers = ref.watch(serversProvider).servers;
    final currentCred = _credId == null
        ? null
        : creds.firstWhereOrNull((c) => c.id == _credId);
    final linkedServer = _serverId == null ? null : servers[_serverId];
    final parsedUri = BmcCfg.parseUri(_addrCtrl.text);

    return Scaffold(
      appBar: CustomAppBar(
        title: MarkedTitle(
          _existing == null ? '${libL10n.add} BMC' : '${libL10n.edit} BMC',
          mark: Feature.bmc.mark(),
        ),
        actions: [
          if (_existing != null)
            Btn.icon(
              text: libL10n.delete,
              icon: const Icon(Icons.delete_outline),
              onTap: _onDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(17, 13, 17, 96),
        children: [
          Input(
            controller: _nameCtrl,
            label: libL10n.name,
            hint: 'BMC / iDRAC / iLO',
            icon: Icons.label_outline,
            autoCorrect: false,
          ),
          UIs.height13,
          Input(
            controller: _addrCtrl,
            label: libL10n.addr,
            hint: 'https://10.0.0.9',
            icon: Icons.link,
            autoCorrect: false,
            type: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
          UIs.height13,
          CardX(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: Text(l10n.bmcAccount),
                  subtitle: Text(
                    currentCred?.name ?? libL10n.empty,
                    style: UIs.text12Grey,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickCredential,
                ),
                ListTile(
                  leading: Icon(
                    _effectiveCertSha256 != null
                        ? Icons.verified_user
                        : Icons.verified_user_outlined,
                  ),
                  title: Text(l10n.bmcCert),
                  subtitle: Text(
                    _effectiveCertSha256 == null
                        ? l10n.bmcCertUnreviewed
                        : '${_effectiveCertSha256!.substring(0, _effectiveCertSha256!.length.clamp(0, 16))}…',
                    style: UIs.text12Grey,
                  ),
                  trailing: _effectiveCertSha256 != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: libL10n.clear,
                          onPressed: () => setState(() {
                            _certSha256 = null;
                            _certAddr = null;
                          }),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: parsedUri == null ? null : _reviewCert,
                ),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(libL10n.server),
                  subtitle: Text(
                    linkedServer?.name ?? libL10n.none,
                    style: UIs.text12Grey,
                  ),
                  trailing: linkedServer != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: libL10n.clear,
                          onPressed: () => setState(() => _serverId = null),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: servers.isEmpty ? null : _pickServer,
                ),
                ValueListenableBuilder<Set<String>>(
                  valueListenable: _tags,
                  builder: (_, tags, _) => ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text(libL10n.tag),
                    subtitle: Text(
                      tags.isEmpty ? libL10n.empty : tags.join(', '),
                      style: UIs.text12Grey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editTags,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'bmc_target_save',
        tooltip: libL10n.save,
        onPressed: _onSave,
        child: const Icon(Icons.save),
      ),
    );
  }

  Future<void> _pickCredential() async {
    final creds = ref.read(bmcCredentialProvider).creds;
    await context.showSheet<void>(
      title: l10n.bmcAccount,
      childBuilder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final cred in creds)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                cred.id == _credId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(cred.name),
              subtitle: Text(cred.user, style: UIs.text12Grey),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () async {
                  ctx.popSheet();
                  await BmcCredentialEditPage.route.go(
                    context,
                    args: BmcCredentialEditPageArgs(cred: cred),
                  );
                },
              ),
              onTap: () {
                setState(() => _credId = cred.id);
                ctx.popSheet();
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add),
            title: Text(libL10n.add),
            onTap: () async {
              ctx.popSheet();
              final created = await BmcCredentialEditPage.route.go(context);
              if (!mounted || created is! BmcCredential) return;
              setState(() => _credId = created.id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _reviewCert() async {
    final addr = _addrCtrl.text.trim();
    final fp = await reviewBmcCert(
      context,
      addr: addr,
      pinned: _effectiveCertSha256,
    );
    if (fp == null || !mounted) return;
    setState(() {
      _certSha256 = fp;
      _certAddr = addr;
    });
  }

  Future<void> _pickServer() async {
    final pick = await pickServerOr<bool>(
      context,
      title: libL10n.server,
      selectedId: _serverId,
      extras: [
        ServerPickerExtra(
          icon: Icons.developer_board,
          title: libL10n.none,
          value: true,
          selected: _serverId == null,
        ),
      ],
    );
    if (!mounted || pick == null) return;
    switch (pick) {
      case PickedExtra():
        setState(() => _serverId = null);
      case PickedServer(:final spi):
        setState(() {
          _serverId = spi.id;
          if (_nameCtrl.text.trim().isEmpty) {
            _nameCtrl.text = spi.name;
          }
        });
    }
  }

  Future<void> _editTags() {
    final all = {
      ...ref.read(serversProvider).tags,
      ...ref.read(bmcTargetsProvider).tags,
    };
    return showTagEditor(
      context,
      tags: _tags,
      allTags: all,
      hint: l10n.tagNewHint,
      listTitle: l10n.tagAllTags,
      matchingTitle: l10n.tagMatching,
      countLabel: l10n.tagOnThisServerFmt,
      createLabel: (needle) =>
          all.contains(needle) ? libL10n.add : l10n.tagCreateFmt(needle),
      noteOf: (tag, selected, matching) => [
        if (selected) l10n.tagOnThisServer,
      ].join(),
    );
  }

  void _onSave() {
    final addr = _addrCtrl.text.trim();
    final existing = _existing;
    final notifier = ref.read(bmcTargetsProvider.notifier);

    if (existing != null) {
      final latest = ref.read(bmcTargetsProvider).targets[existing.id];
      final nameText = _nameCtrl.text.trim();
      final nameChanged = nameText != existing.name.trim();
      final addrChanged = addr != existing.addr.trim();
      final credChanged = _credId != existing.credId;
      final certChanged = _effectiveCertSha256 != existing.certSha256;
      final serverChanged = _serverId != existing.serverId;
      final oldTags = Set<String>.from(existing.tags ?? const []);
      final tagsChanged =
          _tags.value.length != oldTags.length ||
          !_tags.value.containsAll(oldTags);

      if (latest != null &&
          !addrChanged &&
          certChanged &&
          latest.addr.trim() != existing.addr.trim()) {
        Toast.error(libL10n.fail, body: l10n.bmcStaleWrite);
        return;
      }

      final base = latest ?? existing;
      final finalAddr = addrChanged ? addr : base.addr;
      final uri = BmcCfg.parseUri(finalAddr);
      if (uri == null) {
        Toast.error(l10n.bmcAddrInvalid);
        return;
      }
      final finalCredId = credChanged ? _credId : base.credId;
      final creds = ref.read(bmcCredentialProvider).creds;
      final hasCred =
          finalCredId != null &&
          finalCredId.isNotEmpty &&
          creds.any((c) => c.id == finalCredId);
      if (!hasCred) {
        Toast.error(l10n.bmcAccountMissing);
        return;
      }

      final finalName = nameChanged
          ? (nameText.isEmpty ? uri.host : nameText)
          : base.name;
      final finalTags = tagsChanged
          ? (_tags.value.isEmpty ? null : List<String>.from(_tags.value))
          : base.tags;
      final finalCert = addrChanged
          ? _effectiveCertSha256
          : (certChanged ? _effectiveCertSha256 : base.certSha256);

      final merged = BmcTarget(
        id: base.id,
        name: finalName,
        addr: finalAddr,
        credId: finalCredId,
        certSha256: finalCert,
        serverId: serverChanged ? _serverId : base.serverId,
        tags: finalTags,
      );
      if (latest != null) {
        notifier.update(latest, merged);
      } else {
        notifier.add(merged);
      }
      context.pop(merged);
      return;
    }

    final uri = BmcCfg.parseUri(addr);
    if (uri == null) {
      Toast.error(l10n.bmcAddrInvalid);
      return;
    }
    final creds = ref.read(bmcCredentialProvider).creds;
    final hasCred =
        _credId != null &&
        _credId!.isNotEmpty &&
        creds.any((c) => c.id == _credId);
    if (!hasCred) {
      Toast.error(l10n.bmcAccountMissing);
      return;
    }
    final name = _nameCtrl.text.trim().isEmpty
        ? uri.host
        : _nameCtrl.text.trim();
    final tags = _tags.value.isEmpty ? null : List<String>.from(_tags.value);

    final target = BmcTarget(
      id: ShortId.generate(),
      name: name,
      addr: addr,
      credId: _credId,
      certSha256: _effectiveCertSha256,
      serverId: _serverId,
      tags: tags,
    );
    notifier.add(target);
    context.pop(target);
  }

  Future<void> _onDelete() async {
    final existing = _existing;
    if (existing == null) return;
    final ok = await context.showSheet<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('${libL10n.delete} ${existing.name}')),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    ref.read(bmcTargetsProvider.notifier).delete(existing.id);
    context.pop();
  }
}
