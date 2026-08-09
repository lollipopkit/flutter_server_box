import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

/// Declaration order is the default card order on the detail page, and it is
/// also the order `_ServerDetailPageState._cardBuildMap` pairs builders with —
/// the two lists must stay in step.
enum ServerDetailCards {
  /// CPU and RAM, both their current figures and their shared trend. The two
  /// used to be separate `cpu`/`mem` cards that the trend chart then repeated.
  usage(Icons.speed, sinceBuild: 1467),
  diskChart(Icons.stacked_line_chart, sinceBuild: 1467),
  netChart(Icons.multiline_chart, sinceBuild: 1467),
  tempChart(Icons.thermostat, sinceBuild: 1467),
  about(Icons.info),
  swap(Icons.swap_horiz),
  gpu(Bootstrap.gpu_card),
  disk(Bootstrap.device_hdd_fill),
  smart(Icons.health_and_safety, sinceBuild: 1174),
  net(ZondIcons.network),
  sensor(MingCute.dashboard_4_line),
  temp(FontAwesome.temperature_empty_solid),
  battery(Icons.battery_full),
  pve(BoxIcons.bxs_dashboard, sinceBuild: 818),
  custom(Icons.code, sinceBuild: 825);

  final int? sinceBuild;

  final IconData icon;

  const ServerDetailCards(this.icon, {this.sinceBuild});

  static ServerDetailCards? fromName(String str) =>
      ServerDetailCards.values.firstWhereOrNull((e) => e.name == str);

  static final names = values.map((e) => e.name).toList();

  String get toStr => switch (this) {
    usage => libL10n.used,
    about => libL10n.about,
    swap => 'Swap',
    gpu => 'GPU',
    disk => libL10n.disk,
    smart => l10n.diskHealth,
    net => libL10n.net,
    sensor => libL10n.sensors,
    temp => libL10n.temperature,
    battery => libL10n.battery,
    pve => 'PVE',
    custom => libL10n.cmd,
    // Trend-only cards, named apart from the snapshot card of the same subject
    diskChart => '${libL10n.disk} · ${libL10n.stats}',
    netChart => '${libL10n.net} · ${libL10n.stats}',
    tempChart => '${libL10n.temperature} · ${libL10n.stats}',
  };

  /// If:
  /// Version 1 => user set [about], default is [about, cpu]
  /// Version 2 => default is [about, cpu, mem] => auto add [mem] to user's setting
  static void autoAddNewCards(int cur) {
    if (cur >= pve.sinceBuild!) {
      final prop = Stores.setting.detailCardOrder;
      final list = prop.fetch();
      if (!list.contains(pve.name)) {
        list.add(pve.name);
        prop.put(list);
      }
    }

    if (cur >= custom.sinceBuild!) {
      final prop = Stores.setting.detailCardOrder;
      final list = prop.fetch();
      if (!list.contains(custom.name)) {
        list.add(custom.name);
        prop.put(list);
      }
    }

    if (cur >= usage.sinceBuild!) {
      final prop = Stores.setting.detailCardOrder;
      final list = prop.fetch();
      // The separate cpu/mem cards were folded into `usage`; drop their stored
      // entries so the merged card doesn't sit alongside the originals.
      // TODO: remove these three `remove`s once no install can still carry the
      // old names (`monitorHistory` only ever shipped on the frb branch).
      list.removeWhere((e) => e == 'cpu' || e == 'mem' || e == 'monitorHistory');
      // Inserted at the front, not appended: these carry the headline figures
      // and belong above the per-device detail cards.
      for (final card in [usage, diskChart, netChart, tempChart].reversed) {
        if (!list.contains(card.name)) list.insert(0, card.name);
      }
      prop.put(list);
    }
  }
}
