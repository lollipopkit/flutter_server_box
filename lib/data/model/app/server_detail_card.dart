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

  /// Build that folded the standalone trend cards into their snapshot cards.
  static const _kTrendCardsFoldedBuild = 1467;

  /// Adds only cards that first became available during `(from, to]`.
  ///
  /// Looking at [to] alone re-added every old card on every release bump. The
  /// boundary also cannot be the feature branch's commit count: BMC was merged
  /// after v1.0.1491 even though its branch still carried 1491 in BuildData.
  static void autoAddNewCards(int from, int to) {
    final prop = Stores.setting.detailCardOrder;
    final list = prop.fetch();
    final added = [
      for (final card in values)
        if (card.introducedAfterBuild case final boundary?
            when boundary >= from && boundary < to && !list.contains(card.name))
          card.name,
    ];
    if (added.isNotEmpty) {
      list.addAll(added);
      prop.putSync(list);
    }

    if (to >= _kTrendCardsFoldedBuild) {
      // Standalone trend cards, each since folded into the snapshot card of
      // the same subject. These names were only ever written by unreleased
      // builds of this branch, so there is nothing to insert in their place —
      // `initState` drops any name the enum no longer has, but doing it here
      // too keeps the stored list from carrying dead entries around.
      // TODO: drop this block before the names can accumulate meaning.
      final before = list.length;
      list.removeWhere(
        (e) => const {
          'usage',
          'diskChart',
          'tempChart',
          'netChart',
          'monitorHistory',
        }.contains(e),
      );
      if (list.length != before) prop.putSync(list);
    }
  }
}
