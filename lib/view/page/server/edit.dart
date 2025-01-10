import 'dart:convert';

import 'package:choice/choice.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/server.dart';

import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/store/server.dart';

class ServerEditPage extends StatefulWidget {
  final Spi? args;

  const ServerEditPage({super.key, this.args});

  static const route = AppRoute<bool, Spi>(
    page: ServerEditPage.new,
    path: '/server_edit',
  );

  @override
  State<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends State<ServerEditPage> with AfterLayoutMixin {
  late final spi = widget.args;
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
        appBar: AppBar(title: Text(libL10n.edit), actions: actions),
        body: _buildForm(),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildForm() {
    final topItems = [
      _buildWriteScriptTip(),
      if (isMobile) _buildQrScan(),
    ];
    final children = [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: topItems.joinWith(UIs.width13).toList(),
      ),
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
      TagTile(tags: _tags, allTags: ServerProvider.tags.value).cardx,
      ListTile(
        title: Text(l10n.autoConnect),
        trailing: ListenableBuilder(
          listenable: _autoConnect,
          builder: (_, __) => Switch(
            value: _autoConnect.value,
            onChanged: (val) {
              _autoConnect.value = val;
            },
          ),
        ),
      ),
      _buildAuth(),
      _buildJumpServer(),
      _buildMore(),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(17, 7, 17, 47),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildAuth() {
    final switch_ = ListTile(
      title: Text(l10n.keyAuth),
      trailing: ListenableBuilder(
        listenable: _keyIdx,
        builder: (_, __) => Switch(
          value: _keyIdx.value != null,
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
    return ListenableBuilder(
      listenable: _keyIdx,
      builder: (_, __) {
        final children = <Widget>[switch_];
        if (_keyIdx.value != null) {
          children.add(_buildKeyAuth());
        } else {
          children.add(Input(
            controller: _passwordController,
            obscureText: true,
            type: TextInputType.text,
            label: l10n.pwd,
            icon: Icons.password,
            hint: l10n.pwd,
            suggestion: false,
            onSubmitted: (_) => _onSave(),
          ));
        }
        return Column(children: children);
      },
    );
  }

  Widget _buildKeyAuth() {
    return PrivateKeyProvider.pkis.listenVal(
      (pkis) {
        final tiles = List<Widget>.generate(pkis.length, (index) {
          final e = pkis[index];
          return ListTile(
            contentPadding: const EdgeInsets.only(left: 10, right: 15),
            leading: Radio<int>(
              value: index,
              groupValue: _keyIdx.value,
              onChanged: (value) => _keyIdx.value = value,
            ),
            title: Text(e.id, textAlign: TextAlign.start),
            subtitle: Text(
              e.type ?? l10n.unknown,
              textAlign: TextAlign.start,
              style: UIs.textGrey,
            ),
            trailing: Btn.icon(
              icon: const Icon(Icons.edit),
              onTap: () => AppRoutes.keyEdit(pki: e).go(context),
            ),
            onTap: () => _keyIdx.value = index,
          );
        });
        tiles.add(
          ListTile(
            title: Text(libL10n.add),
            contentPadding: const EdgeInsets.only(left: 23, right: 23),
            trailing: const Icon(Icons.add),
            onTap: () => AppRoutes.keyEdit().go(context),
          ),
        );
        return CardX(
          child: ListenableBuilder(
            listenable: _keyIdx,
            builder: (_, __) => Column(children: tiles),
          ),
        );
      },
    );
  }

  Widget _buildEnvs() {
    return _env.listenVal((val) {
      final subtitle =
          val.isEmpty ? null : Text(val.keys.join(','), style: UIs.textGrey);
      return ListTile(
        leading: const Icon(HeroIcons.variable),
        subtitle: subtitle,
        title: Text(l10n.envVars),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () async {
          final res = await KvEditor.route.go(
            context,
            KvEditorArgs(data: spi?.envs ?? {}),
          );
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
          trailing: ListenableBuilder(
            listenable: _pveIgnoreCert,
            builder: (_, __) => Switch(
              value: _pveIgnoreCert.value,
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
        _customCmds.listenVal(
          (vals) {
            return ListTile(
              leading: const Icon(BoxIcons.bxs_file_json),
              title: const Text('JSON'),
              subtitle: vals.isEmpty
                  ? null
                  : Text(vals.keys.join(','), style: UIs.textGrey),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () async {
                final res = await KvEditor.route.go(
                  context,
                  KvEditorArgs(data: _customCmds.value),
                );
                if (res == null) return;
                _customCmds.value = res;
              },
            );
          },
        ).cardx,
        ListTile(
          leading: const Icon(MingCute.doc_line),
          title: Text(libL10n.doc),
          trailing: const Icon(Icons.open_in_new, size: 17),
          onTap: l10n.customCmdDocUrl.launchUrl,
        ).cardx,
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
          label: l10n.pwd,
          icon: Icons.password,
          hint: l10n.pwd,
          suggestion: false,
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _onSave,
      child: const Icon(Icons.save),
    );
  }

  Widget _buildJumpServer() {
    const padding = EdgeInsets.only(left: 13, right: 13, bottom: 7);
    final srvs = ServerProvider.servers.values
        .map((e) => e.value)
        .where((e) => e.spi.jumpId == null)
        .where((e) => e.spi.id != spi?.id)
        .toList();
    final choice = _jumpServer.listenVal(
      (val) {
        final srv = srvs.firstWhereOrNull((e) => e.id == _jumpServer.value);
        return Choice<Server>(
          multiple: false,
          clearable: true,
          value: srv != null ? [srv] : [],
          builder: (state, _) => Wrap(
            children: List<Widget>.generate(
              srvs.length,
              (index) {
                final item = srvs[index];
                return ChoiceChipX<Server>(
                  label: item.spi.name,
                  state: state,
                  value: item,
                  onSelected: (srv, on) {
                    if (on) {
                      _jumpServer.value = srv.spi.id;
                    } else {
                      _jumpServer.value = null;
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
    return ExpandTile(
      leading: const Icon(Icons.map),
      initiallyExpanded: _jumpServer.value != null,
      childrenPadding: padding,
      title: Text(l10n.jumpServer),
      children: [choice],
    ).cardx;
  }

  void _onSave() async {
    if (_ipController.text.isEmpty) {
      context.showSnackBar('${libL10n.empty} ${l10n.host}');
      return;
    }

    if (_keyIdx.value == null && _passwordController.text.isEmpty) {
      final cancel = await context.showRoundDialog<bool>(
        title: libL10n.attention,
        child: Text(libL10n.askContinue(l10n.useNoPwd)),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(libL10n.ok),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(libL10n.cancel),
          )
        ],
      );
      if (cancel != false) return;
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

    final wolEmpty = _wolMacCtrl.text.isEmpty &&
        _wolIpCtrl.text.isEmpty &&
        _wolPwdCtrl.text.isEmpty;
    final wol = wolEmpty
        ? null
        : WakeOnLanCfg(
            mac: _wolMacCtrl.text,
            ip: _wolIpCtrl.text,
            pwd: _wolPwdCtrl.text.selfNotEmptyOrNull,
          );
    if (wol != null) {
      final wolValidation = wol.validate();
      if (!wolValidation.$2) {
        context.showSnackBar('${libL10n.fail}: ${wolValidation.$1}');
        return;
      }
    }

    final spi = Spi(
      name: _nameController.text.isEmpty
          ? _ipController.text
          : _nameController.text,
      ip: _ipController.text,
      port: int.parse(_portController.text),
      user: _usernameController.text,
      pwd: _passwordController.text.selfNotEmptyOrNull,
      keyId: _keyIdx.value != null
          ? PrivateKeyProvider.pkis.value.elementAt(_keyIdx.value!).id
          : null,
      tags: _tags.value.isEmpty ? null : _tags.value.toList(),
      alterUrl: _altUrlController.text.selfNotEmptyOrNull,
      autoConnect: _autoConnect.value,
      jumpId: _jumpServer.value,
      custom: custom,
      wolCfg: wol,
      envs: _env.value.isEmpty ? null : _env.value,
    );

    if (this.spi == null) {
      final existsIds = ServerStore.instance.box.keys;
      if (existsIds.contains(spi.id)) {
        context.showSnackBar('${l10n.sameIdServerExist}: ${spi.id}');
        return;
      }
      ServerProvider.addServer(spi);
    } else {
      ServerProvider.updateServer(this.spi!, spi);
    }

    context.pop();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (spi != null) {
      _initWithSpi(spi!);
    }
  }

  void _initWithSpi(Spi spi) {
    _nameController.text = spi.name;
    _ipController.text = spi.ip;
    _portController.text = spi.port.toString();
    _usernameController.text = spi.user;
    if (spi.keyId == null) {
      _passwordController.text = spi.pwd ?? '';
    } else {
      _keyIdx.value = PrivateKeyProvider.pkis.value.indexWhere(
        (e) => e.id == spi.keyId,
      );
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
        final ret = await BarcodeScannerPage.route.go(
          context,
          args: const BarcodeScannerPageArgs(),
        );
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

  Widget _buildDelBtn() {
    return IconButton(
      onPressed: () {
        context.showRoundDialog(
          title: libL10n.attention,
          child: Text(libL10n.askContinue(
            '${libL10n.delete} ${l10n.server}(${spi!.name})',
          )),
          actions: Btn.ok(
            onTap: () async {
              context.pop();
              ServerProvider.delServer(spi!.id);
              context.pop(true);
            },
            red: true,
          ).toList,
        );
      },
      icon: const Icon(Icons.delete),
    );
  }
}
