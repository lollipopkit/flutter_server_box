import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// The cards the server detail page can draw.
///
/// `cpu`, `mem`, `swap`, `disk` and `net` are no longer cards: the page is
/// built around those five, as one chart and a row each. The names stay
/// because `detailCardDisabled` may still carry them from an older install.
enum ServerDetailCards {
  about(Icons.info),
  cpu(Icons.memory),
  mem(Bootstrap.memory),
  swap(Icons.swap_horiz),
  gpu(Bootstrap.gpu_card),
  disk(Bootstrap.device_hdd_fill),
  smart(Icons.health_and_safety),
  net(ZondIcons.network),
  sensor(MingCute.dashboard_4_line),
  temp(FontAwesome.temperature_empty_solid),
  battery(Icons.battery_full),
  pve(BoxIcons.bxs_dashboard),
  bmc(Icons.developer_board),
  custom(Icons.code);

  final IconData icon;

  const ServerDetailCards(this.icon);

  String get toStr => switch (this) {
    about => libL10n.about,
    cpu => 'CPU',
    mem => 'RAM',
    swap => 'Swap',
    gpu => 'GPU',
    disk => libL10n.disk,
    smart => l10n.diskHealth,
    net => libL10n.net,
    sensor => libL10n.sensors,
    temp => libL10n.temperature,
    battery => libL10n.battery,
    pve => 'PVE',
    bmc => 'BMC',
    custom => libL10n.cmd,
  };

  /// The mark that this card's feature is still in beta, where the card is
  /// *listed* rather than drawn.
  ///
  /// Not on the card itself: that one is drawn beside a name the server page
  /// reads in the same breath as the reading, and carries its own mark. This
  /// is for the row that switches the card on and off.
  Widget? get mark => switch (this) {
    bmc => const BetaTag(),
    _ => null,
  };

  /// [toStr] with [mark], for a row that lists the card rather than drawing it.
  Widget get listTitle {
    final mark_ = mark;
    if (mark_ == null) return Text(toStr);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(toStr, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 7),
        mark_,
      ],
    );
  }
}
