import 'dart:convert';
import 'dart:io';

import 'package:choice/choice.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/core/utils/ssh_config.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/view/page/private_key/edit.dart';

class ServerEditPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs? args;

  const ServerEditPage({super.key, this.args});

  static const route = AppRoute<bool, SpiRequiredArgs>(page: ServerEditPage.new, path: '/servers/edit');

  @override
  ConsumerState<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends ConsumerState<ServerEditPage> with AfterLayoutMixin {
  late final spi = widget.args?.spi;
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _altUrlController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pveAddrCtrl = TextEditingController();
  final _preferTempDevCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _wolMacCtrl = TextEditingController();
  final _wolIpCtrl = TextEditingController();
  final _wolPwdCtrl = TextEditingController();
  final _netDevCtrl = TextEditingController();
  final _scriptDirCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _ipFocus = FocusNode();
  final _alterUrlFocus = FocusNode();
  final _portFocus = FocusNode();
  final _usernameFocus = FocusNode();

  late FocusScopeNode _focusScope;

  /// -1: non selected, null: password, others: index of private key
  final _keyIdx = ValueNotifier<int?>(null);
  final _autoConnect = ValueNotifier(true);
  final _jumpServer = nvn<String?>();
  final _pveIgnoreCert = ValueNotifier(false);
  final _env = <String, String>{}.vn;
  final _customCmds = <String, String>{}.vn;
  final _tags = <String>{}.vn;
  final _systemType = ValueNotifier<SystemType?>(null);
  final _disabledCmdTypes = <String>{}.vn;

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _ipController.dispose();
    _altUrlController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _preferTempDevCtrl.dispose();
    _logoUrlCtrl.dispose();
    _wolMacCtrl.dispose();
    _wolIpCtrl.dispose();
    _wolPwdCtrl.dispose();
    _netDevCtrl.dispose();
    _scriptDirCtrl.dispose();

    _nameFocus.dispose();
    _ipFocus.dispose();
    _alterUrlFocus.dispose();
    _portFocus.dispose();
    _usernameFocus.dispose();
    _pveAddrCtrl.dispose();

    _keyIdx.dispose();
    _autoConnect.dispose();
    _jumpServer.dispose();
    _pveIgnoreCert.dispose();
    _env.dispose();
    _customCmds.dispose();
    _tags.dispose();
    _systemType.dispose();
    _disabledCmdTypes.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusScope = FocusScope.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (spi != null) actions.add(_buildDelBtn());

    return GestureDetector(
      onTap: () => _focusScope.unfocus(),
      child: Scaffold(
        appBar: CustomAppBar(title: Text(libL10n.edit), actions: actions),
        body: _buildForm(),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildForm() {
    final topItems = [_buildWriteScriptTip(), if (isMobile) _buildQrScan(), if (isDesktop) _buildSSHImport()];
    final children = [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: topItems.joinWith(UIs.width13).toList()),
      Input(
        autoFocus: true,
        controller: _nameController,
        type: TextInputType.text,
        node: _nameFocus,
        onSubmitted: (_) => _focusScope.requestFocus(_ipFocus),
        hint: libL10n.example,
        label: libL10n.name,
        icon: BoxIcons.bx_rename,
        obscureText: false,
        autoCorrect: true,
        suggestion: true,
      ),
      Input(
        controller: _ipController,
        type: TextInputType.url,
        onSubmitted: (_) => _focusScope.requestFocus(_portFocus),
        node: _ipFocus,
        label: l10n.host,
        icon: BoxIcons.bx_server,
        hint: 'example.com',
        suggestion: false,
      ),
      Input(
        controller: _portController,
        type: TextInputType.number,
        node: _portFocus,
        onSubmitted: (_) => _focusScope.requestFocus(_usernameFocus),
        label: l10n.port,
        icon: Bootstrap.number_123,
        hint: '22',
        suggestion: false,
      ),
      Input(
        controller: _usernameController,
        type: TextInputType.text,
        node: _usernameFocus,
        onSubmitted: (_) => _focusScope.requestFocus(_alterUrlFocus),
        label: libL10n.user,
        icon: Icons.account_box,
        hint: 'root',
        suggestion: false,
      ),
      TagTile(tags: _tags, allTags: ref.watch(serverNotifierProvider).tags).cardx,
      ListTile(
        title: Text(l10n.autoConnect),
        trailing: _autoConnect.listenVal(
          (val) => Switch(
            value: val,
            onChanged: (val) {
              _autoConnect.value = val;
            },
          ),
        ),
      ),
      _buildAuth(),
      _buildSystemType(),
      _buildJumpServer(),
      _buildMore(),
    ];
    return AutoMultiList(children: children);
  }

  Widget _buildAuth() {
    final switch_ = ListTile(
      title: Text(l10n.keyAuth),
      trailing: _keyIdx.listenVal(
        (v) => Switch(
          value: v != null,
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
    return _keyIdx.listenVal((v) {
      final children = <Widget>[switch_];
      if (v != null) {
        children.add(_buildKeyAuth());
      } else {
        children.add(
          Input(
            controller: _passwordController,
            obscureText: true,
            type: TextInputType.text,
            label: libL10n.pwd,
            icon: Icons.password,
            suggestion: false,
            onSubmitted: (_) => _onSave(),
          ),
        );
      }
      return Column(children: children);
    });
  }

  Widget _buildKeyAuth() {
    final privateKeyState = ref.watch(privateKeyNotifierProvider);
    final pkis = privateKeyState.keys;

    final tiles = List<Widget>.generate(pkis.length, (index) {
      final e = pkis[index];
      return ListTile(
        contentPadding: const EdgeInsets.only(left: 10, right: 15),
        leading: Radio<int>(value: index),
        title: Text(e.id, textAlign: TextAlign.start),
        subtitle: Text(e.type ?? l10n.unknown, textAlign: TextAlign.start, style: UIs.textGrey),
        trailing: Btn.icon(
          icon: const Icon(Icons.edit),
          onTap: () => PrivateKeyEditPage.route.go(context, args: PrivateKeyEditPageArgs(pki: e)),
        ),
        onTap: () => _keyIdx.value = index,
      );
    });
    tiles.add(
      ListTile(
        title: Text(libL10n.add),
        contentPadding: const EdgeInsets.only(left: 23, right: 23),
        trailing: const Icon(Icons.add),
        onTap: () => PrivateKeyEditPage.route.go(context),
      ),
    );
    return RadioGroup<int>(
      onChanged: (val) => _keyIdx.value = val,
      child: _keyIdx.listenVal((_) => Column(children: tiles)).cardx,
    );
  }

  Widget _buildEnvs() {
    return _env.listenVal((val) {
      final subtitle = val.isEmpty ? null : Text(val.keys.join(','), style: UIs.textGrey);
      return ListTile(
        leading: const Icon(HeroIcons.variable),
        subtitle: subtitle,
        title: Text(l10n.envVars),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () async {
          final res = await KvEditor.route.go(context, KvEditorArgs(data: spi?.envs ?? {}));
          if (res == null) return;
          _env.value = res;
        },
      ).cardx;
    });
  }

  Widget _buildMore() {
    return ExpandTile(
      title: Text(l10n.more),
      children: [
        Input(
          controller: _logoUrlCtrl,
          type: TextInputType.url,
          icon: Icons.image,
          label: 'Logo URL',
          hint: 'https://example.com/logo.png',
          suggestion: false,
        ),
        _buildAltUrl(),
        _buildScriptDir(),
        _buildEnvs(),
        _buildPVEs(),
        _buildCustomCmds(),
        _buildDisabledCmdTypes(),
        _buildCustomDev(),
        _buildWOLs(),
      ],
    );
  }

  Widget _buildScriptDir() {
    return Input(
      controller: _scriptDirCtrl,
      type: TextInputType.text,
      label: '${l10n.remotePath} (Shell ${l10n.install})',
      icon: Icons.folder,
      hint: '~/.config/server_box',
      suggestion: false,
    );
  }

  Widget _buildCustomDev() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.specifyDev),
        ListTile(
          leading: const Icon(MingCute.question_line),
          title: TipText(libL10n.note, l10n.specifyDevTip),
        ).cardx,
        Input(
          controller: _preferTempDevCtrl,
          type: TextInputType.text,
          label: l10n.temperature,
          icon: MingCute.low_temperature_line,
          hint: 'nvme-pci-0400',
          suggestion: false,
        ),
        Input(
          controller: _netDevCtrl,
          type: TextInputType.text,
          label: l10n.net,
          icon: ZondIcons.network,
          hint: 'eth0',
          suggestion: false,
        ),
      ],
    );
  }

  Widget _buildSystemType() {
    return _systemType.listenVal((val) {
      return ListTile(
        leading: Icon(MingCute.laptop_2_line),
        title: Text(l10n.system),
        trailing: PopupMenu<SystemType?>(
          initialValue: val,
          items: [
            PopupMenuItem(value: null, child: Text(libL10n.auto)),
            PopupMenuItem(value: SystemType.linux, child: Text('Linux')),
            PopupMenuItem(value: SystemType.bsd, child: Text('BSD')),
            PopupMenuItem(value: SystemType.windows, child: Text('Windows')),
          ],
          onSelected: (value) => _systemType.value = value,
          child: Text(val?.name ?? libL10n.auto, style: TextStyle(color: val == null ? Colors.grey : null)),
        ),
      ).cardx;
    });
  }

  Widget _buildAltUrl() {
    return Input(
      controller: _altUrlController,
      type: TextInputType.url,
      node: _alterUrlFocus,
      label: l10n.fallbackSshDest,
      icon: MingCute.link_line,
      hint: 'user@ip:port',
      suggestion: false,
    );
  }

  Widget _buildPVEs() {
    const addr = 'https://127.0.0.1:8006';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CenterGreyTitle('PVE'),
        Input(
          controller: _pveAddrCtrl,
          type: TextInputType.url,
          icon: MingCute.web_line,
          label: 'URL',
          hint: addr,
          suggestion: false,
        ),
        ListTile(
          leading: const Icon(MingCute.certificate_line),
          title: TipText('PVE ${l10n.ignoreCert}', l10n.pveIgnoreCertTip),
          trailing: _pveIgnoreCert.listenVal(
            (v) => Switch(
              value: v,
              onChanged: (val) {
                _pveIgnoreCert.value = val;
              },
            ),
          ),
        ).cardx,
      ],
    );
  }

  Widget _buildCustomCmds() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.customCmd),
        _customCmds.listenVal((vals) {
          return ListTile(
            leading: const Icon(BoxIcons.bxs_file_json),
            title: const Text('JSON'),
            subtitle: vals.isEmpty ? null : Text(vals.keys.join(','), style: UIs.textGrey),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: _onTapCustomItem,
          );
        }).cardx,
        ListTile(
          leading: const Icon(MingCute.doc_line),
          title: Text(libL10n.doc),
          trailing: const Icon(Icons.open_in_new, size: 17),
          onTap: l10n.customCmdDocUrl.launchUrl,
        ).cardx,
      ],
    );
  }

  Widget _buildDisabledCmdTypes() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle('${libL10n.disabled} ${l10n.cmd}'),
        _disabledCmdTypes.listenVal((disabled) {
          return ListTile(
            leading: const Icon(Icons.disabled_by_default),
            title: Text('${libL10n.disabled} ${l10n.cmd}'),
            subtitle: disabled.isEmpty ? null : Text(disabled.join(', '), style: UIs.textGrey),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: _onTapDisabledCmdTypes,
          );
        }).cardx,
      ],
    );
  }

  Widget _buildWOLs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CenterGreyTitle('Wake On LAN (beta)'),
        ListTile(
          leading: const Icon(BoxIcons.bxs_help_circle),
          title: TipText(libL10n.about, l10n.wolTip),
        ).cardx,
        Input(
          controller: _wolMacCtrl,
          type: TextInputType.text,
          label: 'MAC ${l10n.addr}',
          icon: Icons.computer,
          hint: '00:11:22:33:44:55',
          suggestion: false,
        ),
        Input(
          controller: _wolIpCtrl,
          type: TextInputType.text,
          label: 'IP ${l10n.addr}',
          icon: ZondIcons.network,
          hint: '192.168.1.x',
          suggestion: false,
        ),
        Input(
          controller: _wolPwdCtrl,
          type: TextInputType.text,
          obscureText: true,
          label: libL10n.pwd,
          icon: Icons.password,
          suggestion: false,
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(onPressed: _onSave, child: const Icon(Icons.save));
  }

  Widget _buildJumpServer() {
    const padding = EdgeInsets.only(left: 13, right: 13, bottom: 7);
    final srvs = ref
        .watch(serverNotifierProvider)
        .servers
        .values
        .where((e) => e.jumpId == null)
        .where((e) => e.id != spi?.id)
        .toList();
    final choice = _jumpServer.listenVal((val) {
      final srv = srvs.firstWhereOrNull((e) => e.id == _jumpServer.value);
      return Choice<Spi>(
        multiple: false,
        clearable: true,
        value: srv != null ? [srv] : [],
        builder: (state, _) => Wrap(
          children: List<Widget>.generate(srvs.length, (index) {
            final item = srvs[index];
            return ChoiceChipX<Spi>(
              label: item.name,
              state: state,
              value: item,
              onSelected: (srv, on) {
                if (on) {
                  _jumpServer.value = srv.id;
                } else {
                  _jumpServer.value = null;
                }
              },
            );
          }),
        ),
      );
    });
    return ExpandTile(
      leading: const Icon(Icons.map),
      initiallyExpanded: _jumpServer.value != null,
      childrenPadding: padding,
      title: Text(l10n.jumpServer),
      children: [choice],
    ).cardx;
  }

  Widget _buildWriteScriptTip() {
    return Btn.tile(
      text: libL10n.attention,
      icon: const Icon(Icons.tips_and_updates, color: Colors.grey),
      onTap: () {
        context.showRoundDialog(
          title: libL10n.attention,
          child: SimpleMarkdown(data: l10n.writeScriptTip),
          actions: Btnx.oks,
        );
      },
      textStyle: UIs.textGrey,
      mainAxisSize: MainAxisSize.min,
    );
  }

  Widget _buildQrScan() {
    return Btn.tile(
      text: libL10n.import,
      icon: const Icon(Icons.qr_code, color: Colors.grey),
      onTap: () async {
        final ret = await BarcodeScannerPage.route.go(context, args: const BarcodeScannerPageArgs());
        final code = ret?.text;
        if (code == null) return;
        try {
          final spi = Spi.fromJson(json.decode(code));
          _initWithSpi(spi);
        } catch (e, s) {
          context.showErrDialog(e, s);
        }
      },
      textStyle: UIs.textGrey,
      mainAxisSize: MainAxisSize.min,
    );
  }

  Widget _buildSSHImport() {
    return Btn.tile(
      text: l10n.sshConfigImport,
      icon: const Icon(Icons.settings, color: Colors.grey),
      onTap: _onTapSSHImport,
      textStyle: UIs.textGrey,
      mainAxisSize: MainAxisSize.min,
    );
  }

  Widget _buildDelBtn() {
    return IconButton(
      onPressed: () {
        context.showRoundDialog(
          title: libL10n.attention,
          child: Text(libL10n.askContinue('${libL10n.delete} ${l10n.server}(${spi!.name})')),
          actions: Btn.ok(
            onTap: () async {
              context.pop();
              ref.read(serverNotifierProvider.notifier).delServer(spi!.id);
              context.pop(true);
            },
            red: true,
          ).toList,
        );
      },
      icon: const Icon(Icons.delete),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (spi != null) {
      _initWithSpi(spi!);
    } else {
      // Only for new servers, check SSH config import on first time
      _checkSSHConfigImport();
    }
  }
}

extension _Actions on _ServerEditPageState {
  void _onTapSSHImport() async {
    try {
      final servers = await SSHConfig.parseConfig();
      if (servers.isEmpty) {
        context.showSnackBar(l10n.sshConfigNoServers);
        return;
      }

      dprint('Parsed ${servers.length} servers from SSH config');
      await _processSSHServers(servers);
      dprint('Finished processing SSH config servers');
    } catch (e, s) {
      _handleImportSSHCfgPermissionIssue(e, s);
    }
  }

  void _handleImportSSHCfgPermissionIssue(Object e, StackTrace s) async {
    dprint('Error importing SSH config: $e');
    // Check if it's a permission error and offer file picker as fallback
    if (e is PathAccessException || e.toString().contains('Operation not permitted')) {
      final useFilePicker = await context.showRoundDialog<bool>(
        title: l10n.sshConfigImport,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigPermissionDenied),
            const SizedBox(height: 8),
            Text(l10n.sshConfigManualSelect),
          ],
        ),
        actions: Btnx.cancelOk,
      );

      if (useFilePicker == true) {
        await _onTapSSHImportWithFilePicker();
      }
    } else {
      context.showErrDialog(e, s);
    }
  }

  Future<void> _processSSHServers(List<Spi> servers) async {
    final deduplicated = ServerDeduplication.deduplicateServers(servers);
    final resolved = ServerDeduplication.resolveNameConflicts(deduplicated);
    final summary = ServerDeduplication.getImportSummary(servers, resolved);

    if (!summary.hasItemsToImport) {
      context.showSnackBar(l10n.sshConfigAllExist('${summary.duplicates}'));
      return;
    }

    final shouldImport = await context.showRoundDialog<bool>(
      title: l10n.sshConfigImport,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigFoundServers('${summary.total}')),
            if (summary.hasDuplicates)
              Text(l10n.sshConfigDuplicatesSkipped('${summary.duplicates}'), style: UIs.textGrey),
            Text(l10n.sshConfigServersToImport('${summary.toImport}')),
            const SizedBox(height: 16),
            ...resolved.map((s) => Text('• ${s.name} (${s.user}@${s.ip}:${s.port})')),
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );

    if (shouldImport == true) {
      for (final server in resolved) {
        ref.read(serverNotifierProvider.notifier).addServer(server);
      }
      context.showSnackBar(l10n.sshConfigImported('${resolved.length}'));
    }
  }

  Future<void> _onTapSSHImportWithFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'SSH ${libL10n.select}',
      );

      if (result?.files.single.path case final path?) {
        final servers = await SSHConfig.parseConfig(path);
        if (servers.isEmpty) {
          context.showSnackBar(l10n.sshConfigNoServers);
          return;
        }

        await _processSSHServers(servers);
      }
    } catch (e, s) {
      context.showErrDialog(e, s);
    }
  }

  void _onTapCustomItem() async {
    final res = await KvEditor.route.go(context, KvEditorArgs(data: _customCmds.value));
    if (res == null) return;
    _customCmds.value = res;
  }

  void _onTapDisabledCmdTypes() async {
    final allCmdTypes = ShellCmdType.all;

    // [TimeSeq] depends on the `time` cmd type, so it should be removed from the list
    allCmdTypes.remove(StatusCmdType.time);

    await _showCmdTypesDialog(allCmdTypes);
  }

  void _onSave() async {
    if (_ipController.text.isEmpty) {
      context.showSnackBar('${libL10n.empty} ${l10n.host}');
      return;
    }

    if (_keyIdx.value == null && _passwordController.text.isEmpty) {
      final ok = await context.showRoundDialog<bool>(
        title: libL10n.attention,
        child: Text(libL10n.askContinue(l10n.useNoPwd)),
        actions: Btnx.cancelRedOk,
      );
      if (ok != true) return;
    }

    // If [_pubKeyIndex] is -1, it means that the user has not selected
    if (_keyIdx.value == -1) {
      context.showSnackBar(libL10n.empty);
      return;
    }
    if (_usernameController.text.isEmpty) {
      _usernameController.text = 'root';
    }
    if (_portController.text.isEmpty) {
      _portController.text = '22';
    }
    final customCmds = _customCmds.value;
    final custom = ServerCustom(
      pveAddr: _pveAddrCtrl.text.selfNotEmptyOrNull,
      pveIgnoreCert: _pveIgnoreCert.value,
      cmds: customCmds.isEmpty ? null : customCmds,
      preferTempDev: _preferTempDevCtrl.text.selfNotEmptyOrNull,
      logoUrl: _logoUrlCtrl.text.selfNotEmptyOrNull,
      netDev: _netDevCtrl.text.selfNotEmptyOrNull,
      scriptDir: _scriptDirCtrl.text.selfNotEmptyOrNull,
    );

    final wolEmpty = _wolMacCtrl.text.isEmpty && _wolIpCtrl.text.isEmpty && _wolPwdCtrl.text.isEmpty;
    final wol = wolEmpty
        ? null
        : WakeOnLanCfg(mac: _wolMacCtrl.text, ip: _wolIpCtrl.text, pwd: _wolPwdCtrl.text.selfNotEmptyOrNull);
    if (wol != null) {
      final wolValidation = wol.validate();
      if (!wolValidation.$2) {
        context.showSnackBar('${libL10n.fail}: ${wolValidation.$1}');
        return;
      }
    }

    final spi = Spi(
      name: _nameController.text.isEmpty ? _ipController.text : _nameController.text,
      ip: _ipController.text,
      port: int.parse(_portController.text),
      user: _usernameController.text,
      pwd: _passwordController.text.selfNotEmptyOrNull,
      keyId: _keyIdx.value != null
          ? ref.read(privateKeyNotifierProvider).keys.elementAt(_keyIdx.value!).id
          : null,
      tags: _tags.value.isEmpty ? null : _tags.value.toList(),
      alterUrl: _altUrlController.text.selfNotEmptyOrNull,
      autoConnect: _autoConnect.value,
      jumpId: _jumpServer.value,
      custom: custom,
      wolCfg: wol,
      envs: _env.value.isEmpty ? null : _env.value,
      id: widget.args?.spi.id ?? ShortId.generate(),
      customSystemType: _systemType.value,
      disabledCmdTypes: _disabledCmdTypes.value.isEmpty ? null : _disabledCmdTypes.value.toList(),
    );

    if (this.spi == null) {
      final existsIds = ServerStore.instance.box.keys;
      if (existsIds.contains(spi.id)) {
        context.showSnackBar('${l10n.sameIdServerExist}: ${spi.id}');
        return;
      }
      ref.read(serverNotifierProvider.notifier).addServer(spi);
    } else {
      ref.read(serverNotifierProvider.notifier).updateServer(this.spi!, spi);
    }

    context.pop();
  }
}

extension _Utils on _ServerEditPageState {
  void _checkSSHConfigImport() async {
    final prop = Stores.setting.firstTimeReadSSHCfg;
    // Only check if it's first time and user hasn't disabled it
    if (!prop.fetch()) return;

    try {
      // Check if SSH config exists
      final (_, configExists) = SSHConfig.configExists();
      if (!configExists) return;

      // Ask for permission
      final hasPermission = await context.showRoundDialog<bool>(
        title: l10n.sshConfigImport,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigFound),
            UIs.height7,
            Text(l10n.sshConfigImportPermission),
            UIs.height7,
            Text(l10n.sshConfigImportHelp, style: UIs.textGrey),
          ],
        ),
        actions: Btnx.cancelOk,
      );

      prop.put(false);

      if (hasPermission == true) {
        // Parse and import SSH config
        final servers = await SSHConfig.parseConfig();
        if (servers.isEmpty) {
          context.showSnackBar(l10n.sshConfigNoServers);
          return;
        }

        final deduplicated = ServerDeduplication.deduplicateServers(servers);
        final resolved = ServerDeduplication.resolveNameConflicts(deduplicated);
        final summary = ServerDeduplication.getImportSummary(servers, resolved);

        if (!summary.hasItemsToImport) {
          context.showSnackBar(l10n.sshConfigAllExist('${summary.duplicates}'));
          return;
        }

        // Import without asking again since user already gave permission
        for (final server in resolved) {
          ref.read(serverNotifierProvider.notifier).addServer(server);
        }
        context.showSnackBar(l10n.sshConfigImported('${resolved.length}'));
      }
    } catch (e, s) {
      _handleImportSSHCfgPermissionIssue(e, s);
    }
  }

  Future<void> _showCmdTypesDialog(Set<ShellCmdType> allCmdTypes) {
    return context.showRoundDialog(
      title: '${libL10n.disabled} ${l10n.cmd}',
      child: SizedBox(
        width: 270,
        child: _disabledCmdTypes.listenVal((disabled) {
          return ListView.builder(
            itemCount: allCmdTypes.length,
            itemExtent: 50,
            itemBuilder: (context, index) {
              final cmdType = allCmdTypes.elementAtOrNull(index);
              if (cmdType == null) return UIs.placeholder;
              final display = cmdType.displayName;
              return ListTile(
                leading: Icon(cmdType.sysType.icon, size: 20),
                title: Text(cmdType.name, style: const TextStyle(fontSize: 16)),
                trailing: Checkbox(
                  value: disabled.contains(display),
                  onChanged: (value) {
                    if (value == null) return;
                    if (value) {
                      _disabledCmdTypes.value.add(display);
                    } else {
                      _disabledCmdTypes.value.remove(display);
                    }
                    _disabledCmdTypes.notify();
                  },
                ),
                onTap: () {
                  final isDisabled = disabled.contains(display);
                  if (isDisabled) {
                    _disabledCmdTypes.value.remove(display);
                  } else {
                    _disabledCmdTypes.value.add(display);
                  }
                  _disabledCmdTypes.notify();
                },
              );
            },
          );
        }),
      ),
      actions: Btnx.oks,
    );
  }

  void _initWithSpi(Spi spi) {
    _nameController.text = spi.name;
    _ipController.text = spi.ip;
    _portController.text = spi.port.toString();
    _usernameController.text = spi.user;
    if (spi.keyId == null) {
      _passwordController.text = spi.pwd ?? '';
    } else {
      _keyIdx.value = ref.read(privateKeyNotifierProvider).keys.indexWhere((e) => e.id == spi.keyId);
    }

    /// List in dart is passed by pointer, so you need to copy it here
    _tags.value = spi.tags?.toSet() ?? {};

    _altUrlController.text = spi.alterUrl ?? '';
    _autoConnect.value = spi.autoConnect;
    _jumpServer.value = spi.jumpId;

    final custom = spi.custom;
    if (custom != null) {
      _pveAddrCtrl.text = custom.pveAddr ?? '';
      _pveIgnoreCert.value = custom.pveIgnoreCert;
      _customCmds.value = custom.cmds ?? {};
      _preferTempDevCtrl.text = custom.preferTempDev ?? '';
      _logoUrlCtrl.text = custom.logoUrl ?? '';
    }

    final wol = spi.wolCfg;
    if (wol != null) {
      _wolMacCtrl.text = wol.mac;
      _wolIpCtrl.text = wol.ip;
      _wolPwdCtrl.text = wol.pwd ?? '';
    }

    _env.value = spi.envs ?? {};

    _netDevCtrl.text = spi.custom?.netDev ?? '';
    _scriptDirCtrl.text = spi.custom?.scriptDir ?? '';

    _systemType.value = spi.customSystemType;

    final disabledCmdTypes = spi.disabledCmdTypes?.toSet() ?? {};
    final allAvailableCmdTypes = ShellCmdType.all.map((e) => e.displayName);
    disabledCmdTypes.removeWhere((e) => !allAvailableCmdTypes.contains(e));
    _disabledCmdTypes.value = disabledCmdTypes;
  }
}
