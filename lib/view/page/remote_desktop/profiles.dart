import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/store/entity_store.dart';

final class RemoteDesktopProfilesPage extends ConsumerWidget {
  const RemoteDesktopProfilesPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: RemoteDesktopProfilesPage.new,
    path: '/remote_desktop_profiles',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(remoteDesktopProfilesProvider(args.spi.id));
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(up: 'Remote desktop', down: args.spi.name),
        actions: [
          IconButton(
            tooltip: libL10n.add,
            icon: const Icon(Icons.add),
            onPressed: () => _edit(context, ref),
          ),
        ],
      ),
      body: profiles.isEmpty
          ? _empty(context, ref)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: profiles.length,
              itemBuilder: (_, index) => _tile(context, ref, profiles[index]),
            ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.desktop_windows_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text('No remote desktop profiles', style: UIs.textGrey),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _edit(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add profile'),
        ),
      ],
    ),
  );

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    RemoteDesktopProfile profile,
  ) {
    final open = ref.watch(
      remoteDesktopSessionsProvider.select(
        (state) => state.sessions.containsKey(profile.id),
      ),
    );
    return ListTile(
      leading: Icon(
        profile.protocol == RemoteDesktopProtocol.rdp
            ? Icons.desktop_windows_outlined
            : Icons.connected_tv_outlined,
      ),
      title: Text(profile.name),
      subtitle: Text(
        '${profile.protocol.name.toUpperCase()} · ${profile.host}:${profile.port}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (open) const Icon(Icons.circle, size: 9, color: Colors.green),
          PopupMenuButton<_ProfileAction>(
            onSelected: (action) => switch (action) {
              _ProfileAction.edit => _edit(context, ref, profile),
              _ProfileAction.delete => _delete(context, ref, profile),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _ProfileAction.edit,
                child: Text(libL10n.edit),
              ),
              PopupMenuItem(
                value: _ProfileAction.delete,
                child: Text(libL10n.delete),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _open(context, ref, profile),
    ).cardx.paddingSymmetric(horizontal: 13, vertical: 4);
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    RemoteDesktopProfile profile,
  ) async {
    String? sessionPassword = profile.password;
    if (sessionPassword == null) {
      sessionPassword = await showDialog<String>(
        context: context,
        builder: (_) => _SessionPasswordDialog(
          protocol: profile.protocol,
          username: profile.username,
        ),
      );
      if (sessionPassword == null) return;
    }
    ref.read(remoteDesktopSessionsProvider.notifier).open(
      profile,
      sessionPassword: sessionPassword,
    );
    ref.read(homeTabRequestProvider.notifier).go(AppTab.remoteDesktop);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    RemoteDesktopProfile? existing,
  ]) async {
    final saved = await showDialog<RemoteDesktopProfile>(
      context: context,
      builder: (_) => RemoteDesktopProfileDialog(
        serverId: args.spi.id,
        existing: existing,
      ),
    );
    if (saved == null) return;
    try {
      final notifier = ref.read(remoteDesktopProfilesProvider(args.spi.id).notifier);
      if (existing == null) {
        notifier.add(saved);
      } else {
        notifier.update(existing, saved);
      }
    } on DuplicateNameException {
      if (context.mounted) Toast.show('Profile names must be unique for this server.');
    } catch (error, stackTrace) {
      if (context.mounted) context.showErrDialog(error, stackTrace);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RemoteDesktopProfile profile,
  ) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text('Delete remote desktop profile “${profile.name}”?'),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true) return;
    await ref
        .read(remoteDesktopSessionsProvider.notifier)
        .closeForProfile(profile.id);
    ref
        .read(remoteDesktopProfilesProvider(args.spi.id).notifier)
        .remove(profile);
  }
}

class RemoteDesktopProfileDialog extends StatefulWidget {
  const RemoteDesktopProfileDialog({
    super.key,
    required this.serverId,
    this.existing,
  });

  final String serverId;
  final RemoteDesktopProfile? existing;

  @override
  State<RemoteDesktopProfileDialog> createState() =>
      _RemoteDesktopProfileDialogState();
}

class _RemoteDesktopProfileDialogState
    extends State<RemoteDesktopProfileDialog> {
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

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add remote desktop' : 'Edit remote desktop'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<RemoteDesktopProtocol>(
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
            ),
            const SizedBox(height: 12),
            Input(controller: _name, hint: 'Name'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Input(controller: _host, hint: 'Target host')),
                const SizedBox(width: 8),
                SizedBox(
                  width: 112,
                  child: Input(
                    controller: _port,
                    hint: 'Port',
                    type: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The target is resolved from the SSH server, so localhost refers to that server.',
              style: UIs.text12Grey,
            ),
            const SizedBox(height: 8),
            if (_protocol == RemoteDesktopProtocol.rdp) ...[
              Input(controller: _username, hint: 'Username'),
              const SizedBox(height: 8),
              Input(controller: _domain, hint: 'Domain (optional)'),
              const SizedBox(height: 8),
            ],
            Input(
              controller: _password,
              hint: 'Password (optional)',
              obscureText: true,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Save password'),
              subtitle: const Text('Stored in the encrypted database and backups.'),
              value: _savePassword,
              onChanged: (value) => setState(() => _savePassword = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('View only'),
              value: _viewOnly,
              onChanged: (value) => setState(() => _viewOnly = value),
            ),
            if (_protocol == RemoteDesktopProtocol.vnc)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Share session'),
                value: _shared,
                onChanged: (value) => setState(() => _shared = value),
              ),
          ],
        ),
      ),
    ),
    actions: [Btn.cancel(), Btn.ok(onTap: _save)],
  );

  void _save() {
    final port = int.tryParse(_port.text.trim());
    final error = validateRemoteDesktopProfileInput(
      name: _name.text,
      host: _host.text,
      port: port,
      protocol: _protocol,
      username: _username.text,
      password: _savePassword ? _password.text : '',
    );
    if (error != null) {
      Toast.show(error);
      return;
    }
    final previous = widget.existing;
    final profile = RemoteDesktopProfile(
      id: previous?.id ?? ShortId.generate(),
      serverId: widget.serverId,
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
      trustedCertSha256: previous?.trustedCertSha256,
    ).clearTrustWhenEndpointChanged(previous);
    Navigator.of(context).pop(profile);
  }
}

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

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _SessionPasswordDialog extends StatefulWidget {
  const _SessionPasswordDialog({required this.protocol, this.username});

  final RemoteDesktopProtocol protocol;
  final String? username;

  @override
  State<_SessionPasswordDialog> createState() => _SessionPasswordDialogState();
}

class _SessionPasswordDialogState extends State<_SessionPasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.protocol.name.toUpperCase()} password'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.username case final username?) ...[
          Text(username, style: UIs.text13Grey),
          const SizedBox(height: 8),
        ],
        Input(
          controller: _password,
          hint: 'Password',
          obscureText: true,
          autoFocus: true,
          onSubmitted: (_) => _connect(),
        ),
      ],
    ),
    actions: [
      Btn.cancel(),
      TextButton(
        onPressed: _connect,
        child: Text(
          widget.protocol == RemoteDesktopProtocol.vnc
              ? 'Connect'
              : libL10n.ok,
        ),
      ),
    ],
  );

  void _connect() {
    if (widget.protocol == RemoteDesktopProtocol.vnc) {
      final password = _password.text;
      if (password.codeUnits.length > 8 ||
          password.codeUnits.any((unit) => unit > 0x7f)) {
        Toast.show('Classic VNC passwords are limited to 8 ASCII bytes.');
        return;
      }
    }
    Navigator.of(context).pop(_password.text);
  }
}

enum _ProfileAction { edit, delete }
