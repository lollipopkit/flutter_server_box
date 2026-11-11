part of 'view.dart';

/// One machine found at several addresses: its host key, and each address
/// with the source that found it.
typedef _SameMachine = ({
  String fingerprint,
  List<({String label, DiscoveredSshHost host})> hosts,
});

/// Per machine, the address to connect to and the one to fall back to.
typedef _AddressChoice = ({int primary, int? alternate});

/// Asks, for each machine, which address leads and which is the alternate.
final class _SameMachineDialog extends StatelessWidget {
  const _SameMachineDialog(this.machines, this.choices);

  final List<_SameMachine> machines;
  final List<ValueNotifier<_AddressChoice>> choices;

  /// The choices, or null when dismissed.
  static Future<List<_AddressChoice>?> show(
    BuildContext context,
    List<_SameMachine> machines,
  ) async {
    final choices = [
      for (final m in machines)
        ValueNotifier<_AddressChoice>((
          primary: 0,
          alternate: m.hosts.length > 1 ? 1 : null,
        )),
    ];
    final ok = await context.showSheet<bool>(
      title: l10n.discoverySameMachine,
      // The choices outlive the answer by the sheet's exit: see [DisposeWith].
      child: DisposeWith(
        notifiers: choices,
        child: _SameMachineDialog(machines, choices),
      ),
      actions: Btnx.cancelOk,
    );
    if (ok != true) return null;
    return [for (final c in choices) c.value];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, m) in machines.indexed)
            _buildMachine(m, choices[i]),
        ],
      ),
    );
  }

  Widget _buildMachine(
    _SameMachine m,
    ValueNotifier<_AddressChoice> choice,
  ) {
    String title(int i) =>
        '${m.hosts[i].host.server.name} · ${m.hosts[i].host.address}';
    return choice.listenVal(
      (c) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.fingerprint,
              style: UIs.text12Grey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            _label(l10n.discoveryPrimaryAddress),
            RadioGroup<int>(
              groupValue: c.primary,
              onChanged: (v) {
                if (v == null) return;
                choice.value = (
                  primary: v,
                  // The old lead becomes the fallback when this one was it.
                  alternate: c.alternate == v ? c.primary : c.alternate,
                );
              },
              child: Column(
                children: [
                  for (final (i, h) in m.hosts.indexed)
                    RadioListTile<int>(
                      value: i,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(title(i)),
                      subtitle: Text(h.label, style: UIs.text12Grey),
                    ),
                ],
              ),
            ),
            _label(l10n.discoveryAlternateAddress),
            RadioGroup<int?>(
              groupValue: c.alternate,
              onChanged: (v) =>
                  choice.value = (primary: c.primary, alternate: v),
              child: Column(
                children: [
                  for (final (i, h) in m.hosts.indexed)
                    if (i != c.primary)
                      RadioListTile<int?>(
                        value: i,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(title(i)),
                        subtitle: Text(h.label, style: UIs.text12Grey),
                      ),
                  RadioListTile<int?>(
                    value: null,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(libL10n.none),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
  );
}
