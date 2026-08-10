import 'dart:async';
import 'dart:io';

import 'package:choice/choice.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/jump_chain.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/core/utils/ssh_config.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/view/page/private_key/edit.dart';
import 'package:server_box/view/widget/page_columns.dart';

part 'actions.dart';
part 'widget.dart';

class ServerEditPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs? args;

  const ServerEditPage({super.key, this.args});

  static const route = AppRoute<bool, SpiRequiredArgs>(
    page: ServerEditPage.new,
    path: '/servers/edit',
  );

  @override
  ConsumerState<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends ConsumerState<ServerEditPage>
    with AfterLayoutMixin {
  late final spi = widget.args?.spi;
  late final String _serverId;
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _altUrlController = TextEditingController();
  final _proxyCommandCtrl = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pveAddrCtrl = TextEditingController();
  final _pvePwdCtrl = TextEditingController();
  final _monitorAddrCtrl = TextEditingController();
  final _monitorUserCtrl = TextEditingController();
  final _monitorPwdCtrl = TextEditingController();
  // SSH credentials for the agent's tunnel. Separate controllers from the
  // direct-SSH form above: the two are never on screen together, and sharing
  // them would carry a half-filled direct-SSH form into a tunnel config.
  final _tunnelUserCtrl = TextEditingController();
  final _tunnelPwdCtrl = TextEditingController();
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
  final _proxyCommandFocus = FocusNode();
  final _portFocus = FocusNode();
  final _usernameFocus = FocusNode();

  late FocusScopeNode _focusScope;

  /// -1: non selected, null: password, others: index of private key
  final _keyIdx = ValueNotifier<int?>(null);
  final _autoConnect = ValueNotifier(true);
  final _jumpServers = <String>[].vn;
  final _pveIgnoreCert = ValueNotifier(false);
  final _monitorIgnoreCert = ValueNotifier(false);
  final _passwordlessTerminal = ValueNotifier(false);

  /// Connection method for this server: SSH+shell (false) or monitor's HTTP
  /// API (true) — mutually exclusive, see the switch at the top of the form.
  final _useMonitorHttp = ValueNotifier(false);

  /// Whether to also reach SSH through the agent, for hosts whose SSH port
  /// isn't exposed. Only meaningful alongside [_useMonitorHttp]: it changes
  /// where the SSH *socket* comes from, not how status is read.
  final _sshViaMonitor = ValueNotifier(false);

  /// Key selection for the tunnel's SSH credential; same encoding as
  /// [_keyIdx], kept separate for the same reason the controllers are.
  final _tunnelKeyIdx = ValueNotifier<int?>(null);
  final _tempIsCelsius = ValueNotifier(false);
  final _env = <String, String>{}.vn;
  final _customCmds = <String, String>{}.vn;
  final _tags = <String>{}.vn;
  final _systemType = ValueNotifier<SystemType?>(null);
  final _disabledCmdTypes = <String>{}.vn;
  final _hasStoredSudoPassword = ValueNotifier<bool?>(null);
  String? _pendingSudoPassword;
  bool _sudoPasswordDirty = false;

  @override
  void initState() {
    super.initState();
    _serverId = widget.args?.spi.id ?? ShortId.generate();
    unawaited(_refreshStoredSudoPasswordState());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _altUrlController.dispose();
    _proxyCommandCtrl.dispose();
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
    _proxyCommandFocus.dispose();
    _portFocus.dispose();
    _usernameFocus.dispose();
    _pveAddrCtrl.dispose();
    _pvePwdCtrl.dispose();
    _monitorAddrCtrl.dispose();
    _monitorUserCtrl.dispose();
    _monitorPwdCtrl.dispose();
    _tunnelUserCtrl.dispose();
    _tunnelPwdCtrl.dispose();

    _keyIdx.dispose();
    _autoConnect.dispose();
    _jumpServers.dispose();
    _pveIgnoreCert.dispose();
    _monitorIgnoreCert.dispose();
    _passwordlessTerminal.dispose();
    _useMonitorHttp.dispose();
    _sshViaMonitor.dispose();
    _tunnelKeyIdx.dispose();
    _tempIsCelsius.dispose();
    _env.dispose();
    _customCmds.dispose();
    _tags.dispose();
    _systemType.dispose();
    _disabledCmdTypes.dispose();
    _hasStoredSudoPassword.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusScope = FocusScope.of(context);
  }

  @override
  Widget build(BuildContext context) {
    // The tip is about the form as a whole rather than any one field, so it
    // belongs beside the other page-level action rather than inside the
    // scrolling content, where it took a row of its own and moved away.
    final actions = <Widget>[_buildWriteScriptTip()];
    if (spi != null) actions.add(_buildDelBtn());

    return Scaffold(
      appBar: CustomAppBar(title: Text(libL10n.edit), actions: actions),
      body: GestureDetector(
        onTap: () => _focusScope.unfocus(),
        child: _buildForm(),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildForm() {
    final children = [
      _buildConnMethodSwitch(),
      // The switch is a bare SegmentedButton with no margin of its own, and
      // the fields below it are cards that supply their own. Without this it
      // sits flush against the first one.
      UIs.height13,
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
      _useMonitorHttp.listenVal(
        (useHttp) => useHttp ? UIs.placeholder : _buildSshConnFields(),
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
      _useMonitorHttp.listenVal(
        (useHttp) => useHttp ? _buildMonitorHttp() : _buildAuth(),
      ),
      _useMonitorHttp.listenVal(
        (useHttp) => useHttp
            ? UIs.placeholder
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [_buildSystemType(), _buildJumpServer()],
              ),
      ),
      _buildMore(),
    ];
    return PageColumns(children: children);
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (spi != null) {
      _initWithSpi(spi!);
    } else if (isDesktop && Stores.setting.firstTimeReadSSHCfg.fetch()) {
      _checkSSHConfigImport();
    }
  }
}
