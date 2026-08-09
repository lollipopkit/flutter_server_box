import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

/// Declaration order is the default card order on the detail page, and it is
/// also the order `_ServerDetailPageState._cardBuildMap` pairs builders with —
/// the two lists must stay in step.
enum ServerDetailCards {
  about(Icons.info),
  cpu(Icons.memory),
  mem(Bootstrap.memory),
  diskChart(Icons.stacked_line_chart, sinceBuild: 1467),
  netChart(Icons.multiline_chart, sinceBuild: 1467),
  tempChart(Icons.thermostat, sinceBuild: 1467),
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
    custom => libL10n.cmd,
    // Trend-only cards. Named the same as the snapshot card of the same
    // subject: the header sits on the card the user is already looking at, so
    // a qualifier there is noise. The reorder list in `srv_detail_seq.dart`
    // shows the enum name, which stays distinct.
    diskChart => libL10n.disk,
    netChart => libL10n.net,
    tempChart => libL10n.temperature,
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

    if (cur >= diskChart.sinceBuild!) {
      final prop = Stores.setting.detailCardOrder;
      final list = prop.fetch();
      // Names only ever written by unreleased builds of this branch.
      // TODO: drop these two `remove`s before they can accumulate meaning.
      list.removeWhere((e) => e == 'usage' || e == 'monitorHistory');
      // Inserted after the figures they chart rather than appended, so the
      // trends sit above the per-device detail cards. `cpu`/`mem` are already
      // in every stored list at their original positions.
      final anchor = [mem.name, cpu.name, about.name]
          .map(list.indexOf)
          .firstWhere((i) => i != -1, orElse: () => -1);
      var at = anchor + 1;
      for (final card in [diskChart, netChart, tempChart]) {
        if (list.contains(card.name)) continue;
        list.insert(at, card.name);
        at++;
      }
      prop.put(list);
    }
  }
}
