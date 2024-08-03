import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:provider/provider.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/res/provider.dart';

import '../../../core/route.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/provider/private_key.dart';

class ServerEditPage extends StatefulWidget {
  const ServerEditPage({super.key, this.spi});

  final ServerPrivateInfo? spi;

  @override
  State<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends State<ServerEditPage> with AfterLayoutMixin {
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

  final _nameFocus = FocusNode();
  final _ipFocus = FocusNode();
  final _alterUrlFocus = FocusNode();
  final _portFocus = FocusNode();
  final _usernameFocus = FocusNode();

  late FocusScopeNode _focusScope;

  final _keyIdx = ValueNotifier<int?>(null);
  final _autoConnect = ValueNotifier(true);
  final _jumpServer = ValueNotifier<String?>(null);
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
    _nameFocus.dispose();
    _ipFocus.dispose();
    _alterUrlFocus.dispose();
    _portFocus.dispose();
    _usernameFocus.dispose();
    _pveAddrCtrl.dispose();
    _preferTempDevCtrl.dispose();
    _logoUrlCtrl.dispose();
    _wolMacCtrl.dispose();
    _wolIpCtrl.dispose();
    _wolPwdCtrl.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusScope = FocusScope.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusScope.unfocus(),
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildForm(),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return CustomAppBar(
      title: Text(libL10n.edit),
      actions: widget.spi != null ? [_buildDelBtn()] : null,
    );
  }

  Widget _buildDelBtn() {
    return IconButton(
      onPressed: () {
        context.showRoundDialog(
          title: libL10n.attention,
          child: StatefulBuilder(builder: (ctx, setState) {
            return Text(libL10n.askContinue(
              '${libL10n.delete} ${l10n.server}(${widget.spi!.name})',
            ));
          }),
          actions: Btn.ok(
            onTap: (c) async {
              context.pop();
              Pros.server.delServer(widget.spi!.id);
              context.pop(true);
            },
            red: true,
          ).toList,
        );
      },
      icon: const Icon(Icons.delete),
    );
  }

  Widget _buildForm() {
    final children = [
      _buildWriteScriptTip(),
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
      TagTile(tags: _tags, allTags: Pros.server.tags.value).cardx,
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
    const padding = EdgeInsets.only(left: 23, right: 13);
    return Consumer<PrivateKeyProvider>(
      builder: (_, key, __) {
        final tiles = List<Widget>.generate(key.pkis.length, (index) {
          final e = key.pkis[index];
          return ListTile(
            contentPadding: padding,
            leading: Text(
              '#${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            title: Text(e.id, textAlign: TextAlign.start),
            subtitle: Text(
              e.type ?? l10n.unknown,
              textAlign: TextAlign.start,
              style: UIs.textGrey,
            ),
            trailing: Radio<int>(
              value: index,
              groupValue: _keyIdx.value,
              onChanged: (value) => _keyIdx.value = value,
            ),
            onTap: () => _keyIdx.value = index,
          );
        });
        tiles.add(
          ListTile(
            title: Text(libL10n.add),
            contentPadding: padding,
            trailing: const Padding(
              padding: EdgeInsets.only(right: 13),
              child: Icon(Icons.add),
            ),
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
            args: KvEditorArgs(data: widget.spi?.envs ?? {}),
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
        UIs.height7,
        Input(
          controller: _logoUrlCtrl,
          type: TextInputType.url,
          icon: Icons.image,
          label: 'Logo URL',
          hint: 'https://example.com/logo.png',
          suggestion: false,
        ),
        _buildAltUrl(),
        _buildEnvs(),
        UIs.height7,
        ..._buildPVEs(),
        UIs.height7,
        ..._buildCustomCmds(),
        UIs.height7,
        Text(l10n.temperature, style: UIs.text13Grey),
        UIs.height7,
        Input(
          controller: _preferTempDevCtrl,
          type: TextInputType.text,
          label: libL10n.device,
          icon: MingCute.low_temperature_line,
          hint: 'nvme-pci-0400',
          suggestion: false,
        ),
        UIs.height7,
        ..._buildWOLs(),
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

  List<Widget> _buildPVEs() {
    const addr = 'https://127.0.0.1:8006';
    return [
      const Text('PVE', style: UIs.text13Grey),
      UIs.height7,
      Autocomplete<String>(
        optionsBuilder: (val) {
          final v = val.text;
          if (v.startsWith(addr.substring(0, v.length))) {
            return [addr];
          }
          return [];
        },
        onSelected: (val) => _pveAddrCtrl.text = val,
        fieldViewBuilder: (_, ctrl, node, __) => Input(
          controller: ctrl,
          type: TextInputType.url,
          icon: MingCute.web_line,
          node: node,
          label: 'URL',
          hint: addr,
          suggestion: false,
        ),
      ),
      ListTile(
        leading: const Icon(MingCute.certificate_line),
        title: Text('PVE ${l10n.ignoreCert}'),
        subtitle: Text(l10n.pveIgnoreCertTip, style: UIs.text12Grey),
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
    ];
  }

  List<Widget> _buildCustomCmds() {
    return [
      Text(l10n.customCmd, style: UIs.text13Grey),
      UIs.height7,
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
                args: KvEditorArgs(data: _customCmds.value),
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
        onTap: () => l10n.customCmdDocUrl.launch(),
      ).cardx,
    ];
  }

  List<Widget> _buildWOLs() {
    return [
      const Text('Wake On LAN (beta)', style: UIs.text13Grey),
      UIs.height7,
      ListTile(
        leading: const Icon(BoxIcons.bxs_help_circle),
        title: Text(l10n.about),
        subtitle: Text(l10n.wolTip, style: UIs.text12Grey),
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
    ];
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _onSave,
      child: const Icon(Icons.save),
    );
  }

  Widget _buildJumpServer() {
    return ListenableBuilder(
      listenable: _jumpServer,
      builder: (_, __) {
        final children = Pros.server.servers
            .where((element) => element.spi.jumpId == null)
            .where((element) => element.spi.id != widget.spi?.id)
            .map(
              (e) => ListTile(
                title: Text(e.spi.name),
                subtitle: Text(e.spi.id, style: UIs.textGrey),
                trailing: Radio<String>(
                  groupValue: _jumpServer.value,
                  value: e.spi.id,
                  onChanged: (val) => _jumpServer.value = val,
                ),
                onTap: () => _jumpServer.value = e.spi.id,
                contentPadding: const EdgeInsets.symmetric(horizontal: 17),
              ),
            )
            .toList();
        children.add(ListTile(
          title: Text(libL10n.clear),
          trailing: const Icon(Icons.clear),
          onTap: () => _jumpServer.value = null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 17),
        ));
        return CardX(
          child: ExpandTile(
            leading: const Icon(Icons.map),
            initiallyExpanded: _jumpServer.value != null,
            title: Text(l10n.jumpServer),
            children: children,
          ),
        );
      },
    );
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
      pveAddr: _pveAddrCtrl.text.selfIfNotNullEmpty,
      pveIgnoreCert: _pveIgnoreCert.value,
      cmds: customCmds.isEmpty ? null : customCmds,
      preferTempDev: _preferTempDevCtrl.text.selfIfNotNullEmpty,
      logoUrl: _logoUrlCtrl.text.selfIfNotNullEmpty,
    );

    final wolEmpty = _wolMacCtrl.text.isEmpty &&
        _wolIpCtrl.text.isEmpty &&
        _wolPwdCtrl.text.isEmpty;
    final wol = wolEmpty
        ? null
        : WakeOnLanCfg(
            mac: _wolMacCtrl.text,
            ip: _wolIpCtrl.text,
            pwd: _wolPwdCtrl.text.selfIfNotNullEmpty,
          );
    if (wol != null) {
      final wolValidation = wol.validate();
      if (!wolValidation.$2) {
        context.showSnackBar('${libL10n.fail}: ${wolValidation.$1}');
        return;
      }
    }

    final spi = ServerPrivateInfo(
      name: _nameController.text.isEmpty
          ? _ipController.text
          : _nameController.text,
      ip: _ipController.text,
      port: int.parse(_portController.text),
      user: _usernameController.text,
      pwd: _passwordController.text.selfIfNotNullEmpty,
      keyId: _keyIdx.value != null
          ? Pros.key.pkis.elementAt(_keyIdx.value!).id
          : null,
      tags: _tags.value.isEmpty ? null : _tags.value.toList(),
      alterUrl: _altUrlController.text.selfIfNotNullEmpty,
      autoConnect: _autoConnect.value,
      jumpId: _jumpServer.value,
      custom: custom,
      wolCfg: wol,
      envs: _env.value.isEmpty ? null : _env.value,
    );

    if (widget.spi == null) {
      Pros.server.addServer(spi);
    } else {
      Pros.server.updateServer(widget.spi!, spi);
    }

    context.pop();
  }

  Widget _buildWriteScriptTip() {
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          context.showRoundDialog(
            title: libL10n.attention,
            child: SimpleMarkdown(data: l10n.writeScriptTip),
            actions: [Btn.ok()],
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tips_and_updates, size: 15, color: Colors.grey),
            UIs.width13,
            Text(libL10n.attention, style: UIs.textGrey)
          ],
        ).paddingSymmetric(horizontal: 13, vertical: 3),
      ),
    ).paddingOnly(bottom: 13);
  }

  @override
  void afterFirstLayout(BuildContext context) {
    final spi = widget.spi;
    if (spi != null) {
      _nameController.text = spi.name;
      _ipController.text = spi.ip;
      _portController.text = spi.port.toString();
      _usernameController.text = spi.user;
      if (spi.keyId == null) {
        _passwordController.text = spi.pwd ?? '';
      } else {
        _keyIdx.value = Pros.key.pkis.indexWhere(
          (e) => e.id == widget.spi!.keyId,
        );
      }

      /// List in dart is passed by pointer, so you need to copy it here
      _tags.value = spi.tags?.toSet() ?? {};

      _altUrlController.text = spi.alterUrl ?? '';
      _autoConnect.value = spi.autoConnect ?? true;
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
    }
  }
}
