import 'dart:async';
import 'dart:io';

import 'package:choice/choice.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:redfish/redfish.dart';
import 'package:server_box/core/diag.dart';
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
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
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

  /// The coordinate, as `lat, lon` — see [GeoCoord.tryParse].
  ///
  /// One field rather than two, because that is the shape it gets pasted in:
  /// every map copies a place out as one string with both numbers in it.
  final _geoCtrl = TextEditingController();

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

  /// Tag renames made in the tag editor, from the old name to the new one,
  /// carried out across every server by `_applyTagRenames` when this page is
  /// saved. See `_onRenameTag`.
  final _pendingTagRenames = <String, String>{};
  final _systemType = ValueNotifier<SystemType?>(null);
  final _disabledCmdTypes = <String>{}.vn;
  final _hasStoredSudoPassword = ValueNotifier<bool?>(null);
  String? _pendingSudoPassword;
  bool _sudoPasswordDirty = false;

  @override
  void initState() {
    super.initState();
    _serverId = widget.args?.spi.id ?? ShortId.generate();
    // The open half of a funnel that `edit saved` closes. Without it, giving
    // up partway through adding a server is indistinguishable from never
    // having started -- neither leaves a record of any kind.
    Diag.crumb(
      SbDiag.server,
      'edit opened',
      data: {'mode': widget.args?.spi == null ? 'new' : 'existing'},
    );
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
    _geoCtrl.dispose();

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
      // In the bar, beside the rest of what is done to this page rather than
      // floating over its last row. A form's last field was under the button
      // that saves it, and the agent's own settings page — the one this page's
      // neighbour opens — has always put Save here.
      _buildSaveBtn(),
    ];

    return Scaffold(
      appBar: CustomAppBar(title: Text(libL10n.edit), actions: actions),
      body: GestureDetector(
        onTap: () => _focusScope.unfocus(),
        child: _buildForm(),
      ),
    );
  }

  /// One column, not a grid.
  ///
  /// This was a `PageColumns` masonry, which on a wide window put a method's
  /// switch in one column and its URL in the other — so the two halves of one
  /// decision were side by side with a rule between them, and collapsing
  /// `More` left the left column empty from the fold down. A form is a
  /// sequence of decisions; the only thing a second column can add to it is
  /// distance between a question and its answer.
  Widget _buildForm() {
    // Read here rather than inside the group below: that one is rebuilt by a
    // notifier as well as by this method, and a `ref.watch` reached on the
    // notifier's path is one made outside a build.
    final tagTile = TagTile(
      tags: _tags,
      allTags: ref.watch(serversProvider).tags,
      onEdit: _onEditTags,
    ).cardx;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(13, 7, 13, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Input(
                autoFocus: true,
                controller: _nameController,
                type: TextInputType.text,
                node: _nameFocus,
                onSubmitted: (_) => _focusScope.unfocus(),
                hint: libL10n.example,
                label: libL10n.name,
                icon: BoxIcons.bx_rename,
                obscureText: false,
                autoCorrect: true,
                suggestion: true,
              ),
              tagTile,
              _buildConnectionGroup(),
              // In the order they are dialled, which is the order the list
              // above is in: a section that stayed put while its row moved
              // would make the drag look like it had done nothing.
              _preferMonitorHttp.listenVal(
                (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final method in _methodOrder)
                      _buildMethodSection(method, switch (method) {
                        _Method.monitorHttp => _buildMonitorHttpFields(),
                        _Method.ssh => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [_buildSshConnFields(), _buildAuth()],
                        ),
                      }),
                  ],
                ),
              ),
              _buildBehaviourGroup(),
              _buildOptionalGroup(),
            ],
          ),
        ),
      ),
    );
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
