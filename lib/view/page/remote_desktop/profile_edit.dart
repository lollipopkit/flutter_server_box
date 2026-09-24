// The form's fields are laid out by extensions rather than in the state class's
// own body — see the project's rule on splitting a page into widgets, actions
// and utils — and a switch that changes what the form shows has to call
// `setState` from one of them.
// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/view/widget/group_title.dart';

/// One profile's form: the fields, and the ways out of it.
///
/// A page rather than the dialog this was. Two things decided it: a form with
/// this many fields wants a bar to save from and a corner to act from, and a
/// dialog has neither; and beside the profile list it is the pane's detail
/// (`RemoteDesktopProfilesPage`), where a modal over the list that opened it is
/// the one shape the pane layout exists to avoid.
///
/// Connecting lives in the app bar, not in the list rows: opening a session
/// is what a profile is for, and the action stays visible while the form scrolls.
/// The list rows still offer it, so a profile that is already set up does not
/// have to be opened to be used.
final class RemoteDesktopProfileEditPage extends ConsumerStatefulWidget {
  const RemoteDesktopProfileEditPage({super.key, required this.args});

  final RemoteDesktopProfileEditArgs args;

  static const route = AppRouteArg<void, RemoteDesktopProfileEditArgs>(
    page: RemoteDesktopProfileEditPage.new,
    path: '/remote_desktop_profile/edit',
  );

  @override
  ConsumerState<RemoteDesktopProfileEditPage> createState() =>
      _RemoteDesktopProfileEditPageState();
}

final class RemoteDesktopProfileEditArgs {
  const RemoteDesktopProfileEditArgs({
    required this.serverId,
    this.profile,
    this.onClose,
    this.onTestSessionOpening,
  });

  final String serverId;

  /// The profile being edited, or null for one being added.
  final RemoteDesktopProfile? profile;
  final VoidCallback? onClose;
  final ValueChanged<String?>? onTestSessionOpening;
}

class _RemoteDesktopProfileEditPageState
    extends ConsumerState<RemoteDesktopProfileEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _domain;
  late final TextEditingController _password;
  late RemoteDesktopProtocol _protocol;
  late bool _viewOnly;
  late bool _shared;
  late bool _savePassword;

  /// The id this form will be saved under, made once.
  ///
  /// Not per save: connecting from here opens a session keyed by the profile's
  /// id, so an id that changed on save would leave the session pointing at a
  /// record that no longer exists — and a second Test would open a second
  /// session for one profile.
  late final String _id = widget.args.profile?.id ?? ShortId.generate();

  @override
  void initState() {
    super.initState();
    final existing = widget.args.profile;
    _protocol = existing?.protocol ?? RemoteDesktopProtocol.rdp;
    _name = TextEditingController(text: existing?.name ?? '');
    _host = TextEditingController(text: existing?.host ?? '127.0.0.1');
    _port = TextEditingController(
      text: (existing?.port ?? _protocol.defaultPort).toString(),
    );
    _username = TextEditingController(text: existing?.username ?? '');
    _domain = TextEditingController(text: existing?.domain ?? '');
    _password = TextEditingController(text: existing?.password ?? '');
    _viewOnly = existing?.viewOnly ?? false;
    _shared = existing?.shared ?? true;
    _savePassword = existing?.password != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _domain.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leading: widget.args.onClose == null
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back),
                onPressed: _leave,
              ),
        title: Text(
          widget.args.profile == null
              ? l10n.remoteDesktopAdd
              : l10n.remoteDesktopEdit,
        ),
        actions: _buildActions(),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _buildForm(),
      ),
    );
  }
}

// --- Widgets ---

extension _Widgets on _RemoteDesktopProfileEditPageState {
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(13, 7, 13, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Input(
                controller: _name,
                label: libL10n.name,
                icon: Icons.drive_file_rename_outline,
              ),
              GroupTitle(
                context.l10n.connection,
                right: _protocol.name.toUpperCase(),
              ),
              _buildProtocolPicker(),
              Row(
                children: [
                  Expanded(
                    child: Input(
                      controller: _host,
                      label: libL10n.host,
                      icon: Icons.dns_outlined,
                      suggestion: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 124,
                    child: Input(
                      controller: _port,
                      label: libL10n.port,
                      type: TextInputType.number,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 3, 7),
                child: Text(l10n.remoteDesktopTargetTip, style: UIs.text12Grey),
              ),
              GroupTitle(context.l10n.authShort),
              if (_protocol == RemoteDesktopProtocol.rdp) ...[
                Input(
                  controller: _username,
                  label: libL10n.user,
                  icon: Icons.person_outline,
                ),
                Input(
                  controller: _domain,
                  label: l10n.remoteDesktopDomain,
                  icon: Icons.domain_outlined,
                ),
              ],
              Input(
                controller: _password,
                label: l10n.remoteDesktopPassword,
                icon: Icons.password,
                obscureText: true,
                suggestion: false,
              ),
              _buildSwitch(
                title: l10n.remoteDesktopSavePassword,
                subtitle: l10n.remoteDesktopSavePasswordTip,
                icon: Icons.save_outlined,
                value: _savePassword,
                onChanged: (value) => setState(() => _savePassword = value),
              ),
              GroupTitle(context.l10n.behaviour),
              _buildSwitch(
                title: l10n.remoteDesktopViewOnly,
                icon: Icons.visibility_outlined,
                value: _viewOnly,
                onChanged: (value) => setState(() => _viewOnly = value),
              ),
              if (_protocol == RemoteDesktopProtocol.vnc)
                _buildSwitch(
                  title: l10n.remoteDesktopShareSession,
                  icon: Icons.people_outline,
                  value: _shared,
                  onChanged: (value) => setState(() => _shared = value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle, style: UIs.text12Grey),
    trailing: SwitchX(value: value, onChanged: onChanged),
    onTap: () => onChanged(!value),
  ).cardx;

  Widget _buildProtocolPicker() {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.desktop_windows_outlined),
                const SizedBox(width: 13),
                Text(l10n.remoteDesktopProtocol),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedTabs<RemoteDesktopProtocol>(
              expand: true,
              segments: const [
                SegmentedTab(value: RemoteDesktopProtocol.rdp, label: 'RDP'),
                SegmentedTab(value: RemoteDesktopProtocol.vnc, label: 'VNC'),
              ],
              selected: _protocol,
              onSelected: (next) {
                setState(() {
                  final oldDefault = _protocol.defaultPort.toString();
                  _protocol = next;
                  if (_port.text.isEmpty || _port.text == oldDefault) {
                    _port.text = next.defaultPort.toString();
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- Actions ---

extension _Actions on _RemoteDesktopProfileEditPageState {
  List<Widget> _buildActions() {
    final existing = widget.args.profile;
    return [
      TextButton(
        onPressed: _connect,
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        child: Text(libL10n.test),
      ),
      if (existing != null)
        IconButton(
          onPressed: () => _delete(existing),
          tooltip: libL10n.delete,
          icon: const Icon(Icons.delete),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            visualDensity: VisualDensity.compact,
          ),
          child: Text(libL10n.save),
        ),
      ),
    ];
  }

  Future<void> _save() async {
    final profile = _draft();
    if (profile == null) return;
    final existing = widget.args.profile;
    final notifier = ref.read(
      remoteDesktopProfilesProvider(widget.args.serverId).notifier,
    );
    try {
      if (existing == null) {
        notifier.add(profile);
      } else {
        notifier.update(existing, profile);
      }
    } on DuplicateNameException {
      // The name is unique in the schema rather than in whichever dialog last
      // remembered to check, so this is where a collision is found. The page
      // stays open on the name that has to change.
      Toast.show(l10n.remoteDesktopUniqueName);
      return;
    } catch (error, stackTrace) {
      if (mounted) context.showErrDialog(error, stackTrace);
      return;
    }
    if (!mounted) return;
    _leave();
  }

  Future<void> _delete(RemoteDesktopProfile profile) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.remoteDesktopDeleteProfile(profile.name)),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(remoteDesktopSessionsProvider.notifier)
        .closeForProfile(profile.id);
    ref
        .read(remoteDesktopProfilesProvider(widget.args.serverId).notifier)
        .remove(profile);
    if (!mounted) return;
    _leave();
  }

  /// Opens a session for what the fields say right now, saved or not.
  ///
  /// The draft rather than the stored record, so a host can be corrected and
  /// tried without committing it first. It carries [_id], so saving afterwards updates the
  /// record the session was opened from.
  Future<void> _connect() async {
    // The typed password is validated even when it is not being saved: it is
    // what this connection authenticates with, and a VNC one that is too long
    // or not ASCII would otherwise be sent and refused by the server rather
    // than caught on the field that has to change.
    final profile = _draft(connecting: true);
    if (profile == null || !mounted) return;

    // A session for this id may already be open — carrying the host and
    // password as they were when it started. This button is how corrected
    // fields are tried, so the old connection goes rather than being focused:
    // `open` on an existing id only selects it.
    final sessions = ref.read(remoteDesktopSessionsProvider.notifier);
    if (ref
        .read(remoteDesktopSessionsProvider)
        .sessions
        .containsKey(profile.id)) {
      await sessions.close(profile.id);
      if (!mounted) return;
    }

    try {
      await openRemoteDesktop(
        context,
        ref,
        profile,
        sessionPassword: _password.text,
        onOpening: () => widget.args.onTestSessionOpening?.call(profile.id),
        switchToTab: false,
      );
    } finally {
      widget.args.onTestSessionOpening?.call(null);
    }
  }
}

// --- Utils ---

extension _Utils on _RemoteDesktopProfileEditPageState {
  /// What the fields say, or null after saying why they say nothing usable.
  ///
  /// [connecting] is for Test: it validates the password the typed
  /// field holds rather than only a saved one, because that is the password the
  /// session about to open will present. Saving excludes it when the save
  /// switch is off, which is the whole point of that switch.
  RemoteDesktopProfile? _draft({bool connecting = false}) {
    final port = int.tryParse(_port.text.trim());
    final withPassword = _savePassword || connecting;
    final error = validateRemoteDesktopProfileInput(
      name: _name.text,
      host: _host.text,
      port: port,
      protocol: _protocol,
      username: _username.text,
      password: withPassword ? _password.text : '',
    );
    if (error != null) {
      Toast.show(error);
      return null;
    }
    final existing = widget.args.profile;
    return RemoteDesktopProfile(
      id: _id,
      serverId: widget.args.serverId,
      name: _name.text.trim(),
      protocol: _protocol,
      host: _host.text.trim(),
      port: port!,
      username: _protocol == RemoteDesktopProtocol.rdp
          ? _emptyToNull(_username.text)
          : null,
      domain: _protocol == RemoteDesktopProtocol.rdp
          ? _emptyToNull(_domain.text)
          : null,
      password: _savePassword ? _emptyToNull(_password.text) : null,
      viewOnly: _viewOnly,
      shared: _protocol == RemoteDesktopProtocol.vnc ? _shared : true,
      trustedCertSha256: existing?.trustedCertSha256,
    ).clearTrustWhenEndpointChanged(existing);
  }

  /// Leaves the editor, wherever it is.
  ///
  /// An embedded form returns to its list, a detail closes its pane, and a
  /// pushed page pops its route.
  void _leave() {
    if (widget.args.onClose case final onClose?) {
      onClose();
      return;
    }
    final closePane = PaneScope.closeDetailOf(context);
    if (closePane != null) {
      closePane();
      return;
    }
    context.pop();
  }
}

/// Opens [profile], switching to the remote desktop tab for list actions.
///
/// Shared by the list's rows and the editor's Test action: both have the same
/// question to answer — a profile with no stored password needs one before
/// there is anything to connect with — and answering it twice is how the two
/// would come to disagree.
Future<bool> openRemoteDesktop(
  BuildContext context,
  WidgetRef ref,
  RemoteDesktopProfile profile, {
  String? sessionPassword,
  VoidCallback? onOpening,
  bool switchToTab = true,
}) async {
  var password = sessionPassword?.isNotEmpty == true
      ? sessionPassword
      : profile.password;
  if (password == null) {
    password = await _askPassword(context, profile);
    if (password == null) return false;
  }
  onOpening?.call();
  ref
      .read(remoteDesktopSessionsProvider.notifier)
      .open(profile, sessionPassword: password);
  if (switchToTab) {
    ref.read(homeTabRequestProvider.notifier).go(AppTab.remoteDesktop);
  }
  return true;
}

/// The password a profile without a stored one cannot connect without.
///
/// A profile is not edited through a text field for this: the answer is used
/// once and kept only if the form's save switch says so.
Future<String?> _askPassword(
  BuildContext context,
  RemoteDesktopProfile profile,
) {
  final controller = TextEditingController();
  return context.showRoundDialog<String>(
    title: '${profile.protocol.name.toUpperCase()} ${libL10n.pwd}',
    childBuilder: (dialogContext) => DisposeWith(
      notifiers: [controller],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.username case final username?) ...[
            Text(username, style: UIs.text13Grey),
            const SizedBox(height: 8),
          ],
          Input(
            controller: controller,
            hint: libL10n.pwd,
            obscureText: true,
            autoFocus: true,
            onSubmitted: (value) =>
                _answerPassword(dialogContext, profile, value),
          ),
        ],
      ),
    ),
    actionsBuilder: (dialogContext) => [
      Btn.cancel(),
      TextButton(
        onPressed: () =>
            _answerPassword(dialogContext, profile, controller.text),
        child: Text(
          profile.protocol == RemoteDesktopProtocol.vnc
              ? l10n.connect
              : libL10n.ok,
        ),
      ),
    ],
  );
}

/// Answers the password dialog, or refuses the answer and leaves it open.
///
/// The dialog itself is closed here — the button that was pressed carries an
/// `onTap` of its own, so it is this that has to hand the value over.
void _answerPassword(
  BuildContext dialogContext,
  RemoteDesktopProfile profile,
  String password,
) {
  if (profile.protocol == RemoteDesktopProtocol.vnc &&
      (password.codeUnits.length > 8 ||
          password.codeUnits.any((unit) => unit > 0x7f))) {
    Toast.show(l10n.remoteDesktopVncPasswordLength);
    return;
  }
  dialogContext.popDialog(password);
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// What the form refuses to save, in the words the toast shows.
String? validateRemoteDesktopProfileInput({
  required String name,
  required String host,
  required int? port,
  required RemoteDesktopProtocol protocol,
  required String username,
  required String password,
}) {
  if (name.trim().isEmpty) return l10n.remoteDesktopNameRequired;
  if (host.trim().isEmpty) return l10n.remoteDesktopHostRequired;
  if (port == null || port < 1 || port > 65535) {
    return l10n.remoteDesktopPortRequired;
  }
  if (protocol == RemoteDesktopProtocol.rdp && username.trim().isEmpty) {
    return l10n.remoteDesktopUsernameRequired;
  }
  if (protocol == RemoteDesktopProtocol.vnc && password.codeUnits.length > 8) {
    return l10n.remoteDesktopVncPasswordLength;
  }
  if (protocol == RemoteDesktopProtocol.vnc &&
      password.codeUnits.any((unit) => unit > 0x7f)) {
    return l10n.remoteDesktopVncPasswordAscii;
  }
  return null;
}
