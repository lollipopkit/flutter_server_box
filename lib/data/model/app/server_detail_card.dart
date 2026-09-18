import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// The cards the server detail page can draw.
///
/// `cpu`, `mem`, `swap`, `disk` and `net` are no longer cards: the page is
/// built around those five, as one chart and a row each. The names stay
/// because `detailCardDisabled` may still carry them from an older install.
///
/// TODO: drop `introducedAfterBuild`, which was how a new card was inserted
/// into an order that no longer exists.
enum ServerDetailCards {
  about(Icons.info),
  cpu(Icons.memory),
  mem(Bootstrap.memory),
  swap(Icons.swap_horiz),
  gpu(Bootstrap.gpu_card),
  disk(Bootstrap.device_hdd_fill),
  smart(Icons.health_and_safety, introducedAfterBuild: 1130),
  net(ZondIcons.network),
  sensor(MingCute.dashboard_4_line),
  temp(FontAwesome.temperature_empty_solid),
  battery(Icons.battery_full),
  pve(BoxIcons.bxs_dashboard, introducedAfterBuild: 493),
  bmc(Icons.developer_board, introducedAfterBuild: 1491),
  custom(Icons.code, introducedAfterBuild: 493);

  /// The last released build that did not contain this card.
  final int? introducedAfterBuild;

  final IconData icon;

  const ServerDetailCards(this.icon, {this.introducedAfterBuild});

  static ServerDetailCards? fromName(String str) =>
      ServerDetailCards.values.firstWhereOrNull((e) => e.name == str);

  static final names = values.map((e) => e.name).toList();

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
}
