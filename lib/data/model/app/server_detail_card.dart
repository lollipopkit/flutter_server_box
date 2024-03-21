import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/listx.dart';
import 'package:toolbox/data/model/app/version_related.dart';
import 'package:toolbox/data/res/store.dart';

enum ServerDetailCards implements VersionRelated {
  about,
  cpu,
  mem,
  swap,
  gpu,
  disk,
  net,
  sensor,
  temp,
  battery,
  pve(sinceBuild: 818),
  ;

  @override
  final int? sinceBuild;

  const ServerDetailCards({this.sinceBuild});

  static ServerDetailCards? fromName(String str) =>
      ServerDetailCards.values.firstWhereOrNull((e) => e.name == str);

  static final names = values.map((e) => e.name).toList();

  String get toStr => switch (this) {
        about => l10n.about,
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
      };

  /// If:
  /// Version 1 => user set [about], default is [about, cpu]
  /// Version 2 => default is [about, cpu, mem] => auto add [mem] to user's setting
  static void autoAddNewCards(int cur) {
    if (cur >= pve.sinceBuild!) {
      final prop = Stores.setting.detailCardOrder;
      final list = prop.fetch();
      if (list.contains(pve.name)) return;
      list.add(pve.name);
      prop.put(list);
    }
  }
}
