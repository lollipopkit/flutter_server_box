import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/data/model/app/shell_func.dart';

extension StatusCmdTypeX on StatusCmdType {
  String get i18n => switch (this) {
        StatusCmdType.sys => l10n.system,
        StatusCmdType.host => l10n.host,
        StatusCmdType.uptime => l10n.uptime,
        StatusCmdType.battery => l10n.battery,
        final val => val.name,
      };
}
