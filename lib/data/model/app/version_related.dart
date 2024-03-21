import 'package:toolbox/data/model/app/server_detail_card.dart';

abstract interface class VersionRelated {
  int? get sinceBuild;

  static final funcs = <void Function(int cur)>[
    ServerDetailCards.autoAddNewCards,
  ];
}
