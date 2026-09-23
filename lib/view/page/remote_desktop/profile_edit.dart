// The form's fields are laid out by extensions rather than in the state class's
// own body — see the project's rule on splitting a page into widgets, actions
// and utils — and a switch that changes what the form shows has to call
// `setState` from one of them.
// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/store/entity_store.dart';

/// One profile's form: the fields, and the ways out of it.
///
/// A page rather than the dialog this was. Two things decided it: a form with
/// this many fields wants a bar to save from and a corner to act from, and a
/// dialog has neither; and beside the profile list it is the pane's detail
/// (`RemoteDesktopProfilesPage`), where a modal over the list that opened it is
/// the one shape the pane layout exists to avoid.
///
/// Connecting lives in the corner button, not in the list rows: opening a
/// session is what a profile is *for*, and the corner is what a thumb reaches.
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
  const RemoteDesktopProfileEditArgs({required this.serverId, this.profile});

  final String serverId;

  /// The profile being edited, or null for one being added.
  final RemoteDesktopProfile? profile;
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
  /// record that no longer exists — and a second Connect would open a second
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
        title: Text(
          widget.args.profile == null ? 'Add remote desktop' : 'Edit remote desktop',
        ),
        actions: _buildActions(),
      ),
      body: _buildForm(),
      floatingActionButton: _buildConnectButton(),
    );
  }
}

// --- Widgets ---

extension _Widgets on _RemoteDesktopProfileEditPageState {
  Widget _buildForm() {
    return PageColumns(
      bottomInset: 77,
      children: [
        _buildProtocolPicker(),
        Input(controller: _name, label: libL10n.name),
        Row(
          children: [
            Expanded(child: Input(controller: _host, label: libL10n.host)),
            const SizedBox(width: 8),
            SizedBox(
              width: 112,
              child: Input(
                controller: _port,
                label: libL10n.port,
                type: TextInputType.number,
              ),
            ),
          ],
        ),
        Text(
          'The target is resolved from the SSH server, or from the monitor '
          'agent carrying the connection, so localhost refers to that machine.',
          style: UIs.text12Grey,
        ),
        if (_protocol == RemoteDesktopProtocol.rdp) ...[
          Input(controller: _username, label: 'Username'),
          Input(controller: _domain, label: 'Domain (optional)'),
        ],
        Input(
          controller: _password,
          label: 'Password (optional)',
          obscureText: true,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Save password'),
          subtitle: const Text(
            'Stored in the encrypted database and backups.',
          ),
          value: _savePassword,
          onChanged: (value) => setState(() => _savePassword = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('View only'),
          value: _viewOnly,
          onChanged: (value) => setState(() => _viewOnly = value),
        ),
        if (_protocol == RemoteDesktopProtocol.vnc)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share session'),
            value: _shared,
            onChanged: (value) => setState(() => _shared = value),
          ),
      ],
    );
  }

  Widget _buildProtocolPicker() {
    return SegmentedButton<RemoteDesktopProtocol>(
      segments: const [
        ButtonSegment(value: RemoteDesktopProtocol.rdp, label: Text('RDP')),
        ButtonSegment(value: RemoteDesktopProtocol.vnc, label: Text('VNC')),
      ],
      selected: {_protocol},
      onSelectionChanged: (selected) {
        final next = selected.single;
        setState(() {
          final oldDefault = _protocol.defaultPort.toString();
          _protocol = next;
          if (_port.text.isEmpty || _port.text == oldDefault) {
            _port.text = next.defaultPort.toString();
          }
        });
      },
    );
  }

  Widget _buildConnectButton() {
    return FloatingActionButton(
      heroTag: 'remoteDesktopConnect',
      tooltip: 'Connect',
      onPressed: _connect,
      child: const Icon(Icons.play_arrow),
    );
  }
}

// --- Actions ---

extension _Actions on _RemoteDesktopProfileEditPageState {
  List<Widget> _buildActions() {
    final existing = widget.args.profile;
    return [
      IconButton(
        onPressed: _save,
        tooltip: libL10n.save,
        icon: const Icon(Icons.save),
      ),
      if (existing != null)
        IconButton(
          onPressed: () => _delete(existing),
          tooltip: libL10n.delete,
          icon: const Icon(Icons.delete),
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
      Toast.show('Profile names must be unique for this server.');
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
      child: Text('Delete remote desktop profile “${profile.name}”?'),
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
  /// tried without committing it first — the same loop the snippet editor's run
  /// button exists for. It carries [_id], so saving afterwards updates the
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
    if (ref.read(remoteDesktopSessionsProvider).sessions.containsKey(profile.id)) {
      await sessions.close(profile.id);
      if (!mounted) return;
    }

    await openRemoteDesktop(
      context,
      ref,
      profile,
      sessionPassword: _password.text,
    );
  }
}

// --- Utils ---

extension _Utils on _RemoteDesktopProfileEditPageState {
  /// What the fields say, or null after saying why they say nothing usable.
  ///
  /// [connecting] is for the corner button: it validates the password the typed
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
  /// A pushed page pops. As the content pane's root page there is nothing to
  /// pop — `context.pop()` there does nothing and looks broken — so the way out
  /// is closing the pane, which hands the width back to the list.
  void _leave() {
    final closePane = PaneScope.closeDetailOf(context);
    if (closePane != null) {
      closePane();
      return;
    }
    context.pop();
  }
}

/// Opens [profile] on the remote desktop tab.
///
/// Shared by the list's rows and the editor's corner button: both have the same
/// question to answer — a profile with no stored password needs one before
/// there is anything to connect with — and answering it twice is how the two
/// would come to disagree.
Future<void> openRemoteDesktop(
  BuildContext context,
  WidgetRef ref,
  RemoteDesktopProfile profile, {
  String? sessionPassword,
}) async {
  var password = sessionPassword?.isNotEmpty == true
      ? sessionPassword
      : profile.password;
  if (password == null) {
    password = await _askPassword(context, profile);
    if (password == null) return;
  }
  ref
      .read(remoteDesktopSessionsProvider.notifier)
      .open(profile, sessionPassword: password);
  ref.read(homeTabRequestProvider.notifier).go(AppTab.remoteDesktop);
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
  return context
      .showRoundDialog<String>(
        title: '${profile.protocol.name.toUpperCase()} password',
        childBuilder: (dialogContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.username case final username?) ...[
              Text(username, style: UIs.text13Grey),
              const SizedBox(height: 8),
            ],
            Input(
              controller: controller,
              hint: 'Password',
              obscureText: true,
              autoFocus: true,
              onSubmitted: (value) =>
                  _answerPassword(dialogContext, profile, value),
            ),
          ],
        ),
        actionsBuilder: (dialogContext) => [
          Btn.cancel(),
          TextButton(
            onPressed: () =>
                _answerPassword(dialogContext, profile, controller.text),
            child: Text(
              profile.protocol == RemoteDesktopProtocol.vnc
                  ? 'Connect'
                  : libL10n.ok,
            ),
          ),
        ],
      )
      .whenComplete(controller.dispose);
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
    Toast.show('Classic VNC passwords are limited to 8 ASCII bytes.');
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
  if (name.trim().isEmpty) return 'Enter a profile name.';
  if (host.trim().isEmpty) return 'Enter a target host.';
  if (port == null || port < 1 || port > 65535) return 'Enter a valid port.';
  if (protocol == RemoteDesktopProtocol.rdp && username.trim().isEmpty) {
    return 'Enter the RDP username.';
  }
  if (protocol == RemoteDesktopProtocol.vnc && password.codeUnits.length > 8) {
    return 'Classic VNC passwords are limited to 8 ASCII bytes.';
  }
  if (protocol == RemoteDesktopProtocol.vnc &&
      password.codeUnits.any((unit) => unit > 0x7f)) {
    return 'Classic VNC passwords must contain ASCII characters only.';
  }
  return null;
}
