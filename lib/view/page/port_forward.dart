import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/provider/port_forward_provider.dart';

final class PortForwardPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const PortForwardPage({super.key, required this.args});

  static const route = AppRouteArg<void, SpiRequiredArgs>(page: PortForwardPage.new, path: '/port_forward');

  @override
  ConsumerState<PortForwardPage> createState() => _PortForwardPageState();
}

final class _PortForwardPageState extends ConsumerState<PortForwardPage> {
  late final _notifier = ref.read(portForwardProvider(widget.args.spi).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBetaWarning();
    });
  }

  void _showBetaWarning() {
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text('This feature is still in beta testing. Functionality is not guaranteed.'),
      actions: [Btnx.ok],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(libL10n.portForward),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _onAdd,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final state = ref.watch(portForwardProvider(widget.args.spi));
    final configs = state.configs;

    if (configs.isEmpty) {
      return _buildEmpty();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: configs.length,
      itemBuilder: (context, index) {
        final config = configs[index];
        final status = state.activeForwards[config.id];
        return _buildConfigTile(config, status);
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compare_arrows, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(libL10n.empty, style: UIs.textGrey),
          const SizedBox(height: 8),
          Text('Add a port forward rule to get started', style: UIs.text13Grey),
        ],
      ),
    );
  }

  Widget _buildConfigTile(PortForwardConfig config, PortForwardStatus? status) {
    final isActive = status?.isActive ?? false;
    final hasError = status?.error != null;

    return ListTile(
      leading: Icon(
        isActive ? Icons.link : Icons.link_off,
        color: isActive ? Colors.green : (hasError ? Colors.red : Colors.grey),
      ),
      title: Text(config.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(config.displayAddr, style: UIs.text13Grey),
          if (hasError) Text(status!.error!, style: TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: isActive,
            onChanged: (_) => _notifier.toggleForward(config.id),
          ),
          PopupMenu(
            items: [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 18),
                    const SizedBox(width: 8),
                    Text(libL10n.edit),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete, size: 18),
                    const SizedBox(width: 8),
                    Text(libL10n.delete),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'edit') {
                _onEdit(config);
              } else if (val == 'delete') {
                _onDelete(config);
              }
            },
          ),
        ],
      ),
      isThreeLine: hasError,
    ).cardx.paddingSymmetric(horizontal: 13, vertical: 4);
  }

  void _onAdd() {
    _showConfigDialog(null);
  }

  void _onEdit(PortForwardConfig config) {
    _showConfigDialog(config);
  }

  void _onDelete(PortForwardConfig config) async {
    final sure = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text('Delete ${config.name}?'),
      actions: Btnx.cancelOk,
    );
    if (sure == true) {
      await _notifier.removeConfig(config.id);
    }
  }

  void _showConfigDialog(PortForwardConfig? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final localHostController = TextEditingController(text: existing?.localHost ?? 'localhost');
    final localPortController = TextEditingController(text: existing?.localPort.toString() ?? '');
    final remoteHostController = TextEditingController(text: existing?.remoteHost ?? '');
    final remotePortController = TextEditingController(text: existing?.remotePort.toString() ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');

    context.showRoundDialog(
      title: existing == null ? libL10n.add : libL10n.edit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(controller: nameController, hint: libL10n.name),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Input(controller: localHostController, hint: 'Local Host')),
              const SizedBox(width: 8),
              Expanded(child: Input(controller: localPortController, hint: 'Local Port', type: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Input(controller: remoteHostController, hint: 'Remote Host')),
              const SizedBox(width: 8),
              Expanded(child: Input(controller: remotePortController, hint: 'Remote Port', type: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 8),
          Input(controller: descController, hint: 'Description'),
        ],
      ),
      actions: [
        Btn.cancel(),
        Btn.ok(
          onTap: () async {
            final name = nameController.text.trim();
            final localHost = localHostController.text.trim();
            final localPort = int.tryParse(localPortController.text.trim()) ?? 0;
            final remoteHost = remoteHostController.text.trim();
            final remotePort = int.tryParse(remotePortController.text.trim()) ?? 0;
            final desc = descController.text.trim();

            if (name.isEmpty || localHost.isEmpty || localPort == 0 || remoteHost.isEmpty || remotePort == 0) {
              context.showSnackBar(libL10n.invalid);
              return;
            }

            final config = PortForwardConfig(
              id: existing?.id ?? ShortId.generate(),
              serverId: '',
              name: name,
              localHost: localHost,
              localPort: localPort,
              remoteHost: remoteHost,
              remotePort: remotePort,
              description: desc.isEmpty ? null : desc,
            );

            if (existing == null) {
              await _notifier.addConfig(config);
            } else {
              await _notifier.removeConfig(existing.id);
              await _notifier.addConfig(config);
            }

            if (context.mounted) context.pop();
          },
        ),
      ],
    );
  }
}
