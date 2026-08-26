import 'dart:async';
import 'dart:io';

import 'package:choice/choice.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:redfish/redfish.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/jump_chain.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/core/utils/ssh_config.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/discovery_result.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/view/page/bmc_credential/edit.dart';
import 'package:server_box/view/page/private_key/edit.dart';
import 'package:server_box/view/page/server/custom_cmds.dart';
import 'package:server_box/view/widget/ssh_discovery/dialog.dart';

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
  final _preferTempDevCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _bmcAddrCtrl = TextEditingController();

  /// Which `BmcCredential` this server logs in with, by id.
  ///
  /// An id rather than a user and a password, because a rack shares one
  /// account and this page is where twenty servers would otherwise each get
  /// their own copy of it.
  final _bmcCredId = ValueNotifier<String?>(null);

  /// The certificate fingerprint the user has reviewed, or null.
  ///
  /// Not a text field: nobody types a fingerprint. It is set by the review
  /// step, which reads what the BMC actually presents — see `cert_pin.dart`
  /// for why that has to be a separate step from enforcing it.
  final _bmcCert = ValueNotifier<String?>(null);

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

  /// -1: key auth enabled without a selection, null: key auth disabled,
  /// others: index of private key
  final _keyIdx = ValueNotifier<int?>(null);

  /// A key file on this machine, as `~/.ssh/config` named one — see
  /// `SshCredential.keyPath`. Not a selection among stored keys, which is what
  /// [_keyIdx] is, and mutually exclusive with it.
  ///
  /// Held here so that opening an imported server and saving it does not
  /// quietly drop the key it was connecting with.
  final _keyPath = ValueNotifier<String?>(null);
  final _autoConnect = ValueNotifier(true);
  final _jumpServers = <String>[].vn;
  final _pveIgnoreCert = ValueNotifier(false);
  final _monitorIgnoreCert = ValueNotifier(false);
  final _monitorAllowInsecure = ValueNotifier(false);

  /// Connection method for this server: SSH+shell (false) or monitor's HTTP
  /// API (true) — mutually exclusive, see the switch at the top of the form.
  /// The two ways in, each switched on independently.
  ///
  /// They used to be one boolean, because a server could carry exactly one.
  /// Both at once is now a configuration someone can ask for — an agent for
  /// status without a shell open, sshd for the things the agent has no
  /// endpoint for — so what is left of the old exclusivity is
  /// [_preferMonitorHttp], which orders them rather than excluding either.
  final _useSsh = ValueNotifier(true);
  final _useMonitorHttp = ValueNotifier(false);

  /// Which one is tried first. Only shown, and only stored, when both are on.
  final _preferMonitorHttp = ValueNotifier(false);

  /// Which protocol this server's files move over — see [SshFileTransport].
  ///
  /// A field of the SSH credential rather than a preference, so it lives here
  /// beside `ProxyCommand` and the fallback address: all three are "how this
  /// one host has to be talked to", and none of them is a question the app can
  /// answer by itself.
  final _fileTransport = ValueNotifier(SshFileTransport.sftp);

  final _tempIsCelsius = ValueNotifier(false);
  final _env = <String, String>{}.vn;

  /// Custom commands an older version of the app stored here, carried through
  /// a save unchanged so that editing anything else on this page does not
  /// discard them before the first connection moves them to the server.
  ///
  /// Not edited here any more — the editor writes the server directly, since
  /// the directory there is the only copy.
  // TODO(migration): delete with [ServerCustom.cmds].
  final _unmigratedCmds = <String, String>{}.vn;
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
    _bmcAddrCtrl.dispose();
    _bmcCredId.dispose();
    _bmcCert.dispose();
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

    _keyIdx.dispose();
    _keyPath.dispose();
    _autoConnect.dispose();
    _jumpServers.dispose();
    _pveIgnoreCert.dispose();
    _monitorIgnoreCert.dispose();
    _monitorAllowInsecure.dispose();
    _useSsh.dispose();
    _useMonitorHttp.dispose();
    _preferMonitorHttp.dispose();
    _fileTransport.dispose();
    _tempIsCelsius.dispose();
    _env.dispose();
    _unmigratedCmds.dispose();
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
    final actions = <Widget>[
      // Only while adding. Sweeping the network for hosts is how someone with
      // an empty form finds what to put in it; on a server that already exists
      // it answers a question nobody is asking.
      if (spi == null) _buildDiscoverBtn(),
      _buildWriteScriptTip(),
      if (spi != null) _buildDelBtn(),
    ];

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
      // The name is in the same group of cards as the SSH fields rather than
      // a card of its own above them. Cards within a group sit against each
      // other; a card that is its own [PageColumns] child gets the grid's
      // spacing on top of that, which read as a gap belonging to nothing.
      //
      // It also means this entry always has something in it. An entry that
      // renders to an empty box still gets spacing on both sides of it, so
      // the placeholder this used to be left a wider gap behind than the
      // fields it stood in for.
      _useSsh.listenVal(
        (useSsh) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            if (useSsh) _buildSshConnFields(),
          ],
        ),
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
      // The rest of the connection fields, as one group rather than three
      // entries. Which of them are shown is up to the two switches, and each
      // one that was its own [PageColumns] child left the grid's spacing
      // behind when it rendered to nothing — an SSH-only server showed a gap
      // between the password and the system type, held open by monitor
      // fields that were not there.
      ListenableBuilder(
        listenable: Listenable.merge([_useSsh, _useMonitorHttp]),
        builder: (_, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_useSsh.value) _buildAuth(),
            if (_useMonitorHttp.value) _buildMonitorHttp(),
            if (_useSsh.value) ...[_buildSystemType(), _buildJumpServer()],
          ],
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
