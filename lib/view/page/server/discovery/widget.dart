part of 'discovery.dart';

class _DiscoverySettingsDialog extends StatefulWidget {
  final SshDiscoveryConfig config;
  final ValueChanged<SshDiscoveryConfig> onChanged;

  const _DiscoverySettingsDialog({
    required this.config,
    required this.onChanged,
  });

  @override
  State<_DiscoverySettingsDialog> createState() => _DiscoverySettingsDialogState();
}

class _DiscoverySettingsDialogState extends State<_DiscoverySettingsDialog> {
  late final _timeoutController = TextEditingController(text: widget.config.timeoutMs.toString());
  late final _concurrencyController = TextEditingController(text: widget.config.maxConcurrency.toString());
  late bool _enableMdns = widget.config.enableMdns;

  @override
  void dispose() {
    _timeoutController.dispose();
    _concurrencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.discoverySettings,
          style: const TextStyle(fontSize: 18),
        ),
        UIs.height13,
        Input(
          controller: _timeoutController,
          type: TextInputType.number,
          label: '${libL10n.timeout} (ms)',
          onChanged: (v) {
            final t = int.tryParse(v) ?? 700;
            if (t > 0) {
              widget.onChanged(widget.config.copyWith(timeoutMs: t));
            }
          },
          hint: '700',
        ),
        UIs.height7,
        Input(
          controller: _concurrencyController,
          type: TextInputType.number,
          label: l10n.maxConcurrency,
          hint: '128',
          onChanged: (v) {
            final c = int.tryParse(v) ?? 128;
            if (c > 0) {
              widget.onChanged(widget.config.copyWith(maxConcurrency: c));
            }
          },
        ),
        UIs.height7,
        SwitchListTile(
          title: Text(l10n.enableMdns),
          subtitle: Text(l10n.enableMdnsDesc),
          value: _enableMdns,
          onChanged: (value) {
            setState(() {
              _enableMdns = value;
            });
            widget.onChanged(widget.config.copyWith(enableMdns: value));
          },
        ),
      ],
    );
  }
}