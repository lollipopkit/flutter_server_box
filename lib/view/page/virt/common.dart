import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';

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
      VirtErrType.unknown => message,
      VirtErrType.notConfigured => l10n.virtErrNotConfiguredTip,
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
