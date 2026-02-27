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
import 'package:server_box/data/model/server/discovery_result.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/view/page/private_key/edit.dart';
import 'package:server_box/view/page/server/discovery/discovery.dart';

part 'actions.dart';
part 'widget.dart';

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
    final topItems = [
      _buildWriteScriptTip(),
      if (isMobile) _buildQrScan(),
      if (isDesktop) _buildSSHImport(),
      _buildSSHDiscovery(),
    ];
    final children = [
      SizedBox(
        height: 50,
        child: ListView(scrollDirection: Axis.horizontal, children: topItems.joinWith(UIs.width13).toList()),
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
        label: libL10n.host,
        icon: BoxIcons.bx_server,
        hint: 'example.com',
        suggestion: false,
      ),
      Input(
        controller: _portController,
        type: TextInputType.number,
        node: _portFocus,
        onSubmitted: (_) => _focusScope.requestFocus(_usernameFocus),
        label: libL10n.port,
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
      TagTile(tags: _tags, allTags: ref.watch(serversProvider).tags).cardx,
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
