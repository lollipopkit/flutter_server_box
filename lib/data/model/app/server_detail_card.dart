import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

enum ServerDetailCards {
  about(Icons.info),
  cpu(Icons.memory),
  mem(Bootstrap.memory),
  swap(Icons.swap_horiz),
  gpu(Bootstrap.gpu_card),
  disk(Bootstrap.device_hdd_fill),
  net(ZondIcons.network),
  sensor(MingCute.dashboard_4_line),
  temp(FontAwesome.temperature_empty_solid),
  battery(Icons.battery_full),
  pve(BoxIcons.bxs_dashboard, sinceBuild: 818),
  custom(Icons.code, sinceBuild: 825),
  ;

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
        disk => l10n.disk,
        net => l10n.net,
        sensor => l10n.sensors,
        temp => l10n.temperature,
        battery => l10n.battery,
        pve => 'PVE',
        custom => l10n.cmd,
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
  }
}
