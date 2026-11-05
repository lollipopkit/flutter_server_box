import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/widget/progress_line.dart';

/// What the Virtualization tab calls a guest's state, and how it marks it.
extension VirtGuestStateUi on VirtGuestState {
  String get label => switch (this) {
    VirtGuestState.running => libL10n.running,
    VirtGuestState.paused => l10n.virtPaused,
    VirtGuestState.stopped => libL10n.stopped,
    VirtGuestState.starting => l10n.virtStarting,
    VirtGuestState.stopping => l10n.virtStopping,
    VirtGuestState.rebooting => l10n.virtRebooting,
    VirtGuestState.migrating => l10n.virtMigrating,
    VirtGuestState.backup => l10n.virtBackingUp,
    VirtGuestState.unknown => libL10n.unknown,
  };

  /// [StatePalette]'s, so a guest reads the way a server or a unit does.
  Color get color => switch (this) {
    VirtGuestState.running => StatePalette.running,
    VirtGuestState.stopped || VirtGuestState.unknown => StatePalette.idle,
    VirtGuestState.paused ||
    VirtGuestState.starting ||
    VirtGuestState.stopping ||
    VirtGuestState.rebooting ||
    VirtGuestState.migrating ||
    VirtGuestState.backup => StatePalette.warn,
  };

  IconData get icon => switch (this) {
    VirtGuestState.running => Icons.play_circle_outline,
    VirtGuestState.paused => Icons.pause_circle_outline,
    VirtGuestState.stopped => Icons.stop_circle_outlined,
    VirtGuestState.migrating => Icons.sync_alt,
    VirtGuestState.starting ||
    VirtGuestState.stopping ||
    VirtGuestState.rebooting ||
    VirtGuestState.backup => Icons.pending_outlined,
    VirtGuestState.unknown => Icons.help_outline,
  };
}

/// What a power action is called and drawn as.
extension VirtPowerActionUi on VirtPowerAction {
  String get label => switch (this) {
    VirtPowerAction.start => libL10n.start,
    VirtPowerAction.shutdown => libL10n.shutdown,
    VirtPowerAction.reboot => libL10n.reboot,
    // The BMC's word for the same thing: power cut, no ACPI request first.
    VirtPowerAction.forceStop => l10n.bmcForceOff,
    VirtPowerAction.suspend => libL10n.suspend,
    VirtPowerAction.resume => l10n.virtResume,
  };

  IconData get icon => switch (this) {
    VirtPowerAction.start => Icons.play_arrow,
    VirtPowerAction.resume => Icons.play_arrow,
    VirtPowerAction.shutdown => Icons.power_settings_new,
    VirtPowerAction.reboot => Icons.restart_alt,
    VirtPowerAction.forceStop => Icons.power_off,
    VirtPowerAction.suspend => Icons.pause,
  };

  /// The order they sit in on a bar: the way in first, the way out last, and
  /// the one that loses data at the very end, where it is hardest to hit by
  /// accident.
  static const barOrder = [
    VirtPowerAction.start,
    VirtPowerAction.resume,
    VirtPowerAction.suspend,
    VirtPowerAction.reboot,
    VirtPowerAction.shutdown,
    VirtPowerAction.forceStop,
  ];
}

extension VirtGuestKindUi on VirtGuestKind {
  String get label => switch (this) {
    VirtGuestKind.qemu => 'QEMU',
    VirtGuestKind.lxc => 'LXC',
  };

  IconData get icon => switch (this) {
    VirtGuestKind.qemu => Icons.desktop_windows_outlined,
    VirtGuestKind.lxc => Icons.inventory_2_outlined,
  };
}

extension VirtHostKindUi on VirtHostKind {
  String get label => switch (this) {
    VirtHostKind.pve => 'Proxmox VE',
    VirtHostKind.libvirt => 'libvirt',
  };
}

/// How the tab talks about a failure.
///
/// Titled by [VirtErr.type], always in the user's language. The message is
/// shown under it only where it is the host's own words — PVE's refusal,
/// virsh's error — and not where the backend wrote it for a log, which is
/// English and says nothing the title does not.
extension VirtErrUi on VirtErr {
  String get title => switch (type) {
    VirtErrType.unreachable => l10n.virtErrUnreachable,
    VirtErrType.notConfigured => l10n.virtErrNotConfigured,
    VirtErrType.serverRemoved => l10n.virtErrServerRemoved,
    VirtErrType.authFailed => l10n.virtErrAuthFailed,
    VirtErrType.needTfa => l10n.pveOtpTitle,
    VirtErrType.certUnconfirmed => l10n.virtErrCertUnconfirmed,
    VirtErrType.certChanged => l10n.virtErrCertChanged,
    VirtErrType.relayNotGranted => l10n.virtErrRelayNotGranted,
    VirtErrType.execNotGranted => l10n.virtErrExecNotGranted,
    VirtErrType.notInstalled => l10n.virtErrNotInstalled,
    VirtErrType.permissionDenied => libL10n.permissionDenied,
    VirtErrType.sudoPasswordRequired => l10n.virtErrSudoRequired,
    VirtErrType.sudoPasswordRejected => l10n.virtErrSudoRejected,
    VirtErrType.invalidResponse => l10n.virtErrInvalidResponse,
    VirtErrType.actionFailed => l10n.virtErrActionFailed,
    VirtErrType.unsupported => libL10n.unsupported,
    VirtErrType.exists => l10n.virtErrExists,
    VirtErrType.conflict => l10n.virtErrConflict,
    VirtErrType.unknown => libL10n.error,
  };

  /// The line under [title]: the host's text, or what to do about it.
  String? get detail {
    final hostText = switch (type) {
      VirtErrType.unreachable ||
      VirtErrType.authFailed ||
      VirtErrType.needTfa ||
      VirtErrType.permissionDenied ||
      VirtErrType.invalidResponse ||
      VirtErrType.actionFailed ||
      VirtErrType.exists ||
      VirtErrType.unknown => message,
      VirtErrType.notConfigured => l10n.virtErrNotConfiguredTip,
      VirtErrType.conflict => l10n.virtErrConflictTip,
      _ => null,
    };
    final parts = [
      if (hostText != null && hostText.isNotEmpty) hostText,
      if (solution case final solution? when solution.isNotEmpty) solution,
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }
}

/// A dot in a state's colour, the mark a guest carries in every list.
class VirtStateDot extends StatelessWidget {
  const VirtStateDot(this.state, {super.key, this.size = 7});

  final VirtGuestState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: state.label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: state.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// A titled card of facts, the shape every card in a detail view has.
class VirtCard extends StatelessWidget {
  const VirtCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  /// Beside the title: a count, a state, an action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: ChartPalette.accent),
                UIs.width7,
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UIs.text13Bold,
                  ),
                ),
                ?trailing,
              ],
            ),
            UIs.height7,
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One fact: its name on the left, its value on the right.
class VirtFact extends StatelessWidget {
  const VirtFact(this.k, this.v, {super.key});

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: UIs.text12Grey),
          UIs.width13,
          Expanded(
            child: SelectableText(
              v,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tag: a kind, a flag, a state.
class VirtChip extends StatelessWidget {
  const VirtChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text, style: UIs.text11Grey),
    );
  }
}

/// The guest [ref] names, among [guests].
VirtGuest? virtGuestOf(List<VirtGuest> guests, VirtGuestRef ref) {
  final id = ref.guestId;
  if (id != null) return guests.firstWhereOrNull((g) => g.id == id);
  final vmid = ref.vmid;
  if (vmid == null) return null;
  return guests.firstWhereOrNull((g) => g.vmid == vmid);
}

/// [ref]'s guest by name, or what the host said of it when it is not in the
/// list (a guest this account may not see).
String virtGuestLabel(List<VirtGuest> guests, VirtGuestRef ref) =>
    virtGuestOf(guests, ref)?.name ??
    ref.vmid?.toString() ??
    ref.guestId?.split('-').first ??
    '?';

extension VirtNetworkModeUi on VirtNetwork {
  /// libvirt's forward modes by what they do; PVE's interface types by
  /// PVE's own names for them.
  String get modeLabel => switch (mode) {
    'nat' => 'NAT',
    'isolated' => l10n.virtNetIsolated,
    'bridge' when node == null => l10n.virtNetBridged,
    'route' => l10n.virtNetRouted,
    'bridge' => 'Linux Bridge',
    'bond' => 'Linux Bond',
    'vlan' => 'Linux VLAN',
    'eth' => 'Ethernet',
    final m => m,
  };

  /// Guests attach here: every libvirt network, and a PVE bridge.
  bool get takesGuests =>
      node == null || mode == 'bridge' || mode == 'OVSBridge';
}

/// A list under the section pills: progress, failure, rows, pull to refresh.
class VirtResourceColumn extends StatelessWidget {
  const VirtResourceColumn({
    super.key,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.children,
  });

  final bool loading;
  final Object? error;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final err = error;
    return Column(
      children: [
        SizedBox(height: 3, child: loading ? const ProgressLine() : null),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(9, 5, 9, 17),
              children: [
                if (err != null) VirtErrCard(err, onRetry: onRefresh),
                if (loading && children.isEmpty && err == null)
                  const Padding(
                    padding: EdgeInsets.all(27),
                    child: Center(child: SizedLoading.medium),
                  ),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A failure where a list or a card would be, with a way to ask again.
class VirtErrCard extends StatelessWidget {
  const VirtErrCard(this.error, {super.key, this.onRetry});

  final Object error;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    final retry = onRetry;
    return VirtCard(
      icon: Icons.error_outline,
      title: e is VirtErr ? e.title : libL10n.error,
      trailing: retry == null
          ? null
          : Btn.icon(
              text: libL10n.retry,
              icon: const Icon(Icons.refresh, size: 18),
              onTap: () async {
                try {
                  await retry();
                } catch (_) {
                  // A retry that fails again is this card's error, shown by
                  // whatever it comes from.
                }
              },
            ),
      children: [
        if (e is! VirtErr)
          Text('$e', style: UIs.text12Grey)
        else if (e.detail case final d?)
          Text(d, style: UIs.text12Grey),
      ],
    );
  }
}

/// A pool or a network in the list column, drawn like a guest row.
class VirtResourceRow extends StatelessWidget {
  const VirtResourceRow({
    super.key,
    required this.icon,
    required this.active,
    required this.name,
    required this.meta,
    required this.sub,
    required this.selected,
    required this.onTap,
    this.metaIcon,
  });

  final IconData icon;
  final bool active;
  final String name;
  final String meta;
  final IconData? metaIcon;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  static final _radius = BorderRadius.circular(9);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: _radius,
        child: InkWell(
          borderRadius: _radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 11, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: active ? StatePalette.running : StatePalette.idle,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
                    ),
                    UIs.width7,
                    if (metaIcon case final i?) ...[
                      Icon(i, size: 13, color: Colors.grey),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      meta,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 23, top: 2),
                    child: Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UIs.text11Grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar of a pool or network detail, or of a form for a new one: its name
/// — which opens the others where [onSwitch] is given — its [actions], and a
/// refresh where [onRefresh] is given.
PreferredSizeWidget virtResourceBar({
  required String name,
  required IconData icon,
  Widget? leading,
  int? position,
  int total = 0,
  VoidCallback? onSwitch,
  List<BarAction> actions = const [],
  VoidCallback? onRefresh,
}) {
  return SwitcherBar(
    leading: leading,
    switcher: SessionSwitcherLabel(
      name: name,
      icon: icon,
      position: position,
      total: total,
      onTap: onSwitch,
    ),
    actions: [
      ...actions,
      if (onRefresh != null)
        BarAction(
          icon: Icons.refresh,
          label: libL10n.refresh,
          onTap: onRefresh,
        ),
    ],
  );
}
