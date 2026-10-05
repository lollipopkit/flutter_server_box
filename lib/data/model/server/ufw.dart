import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/server/firewall.dart';

export 'package:server_box/data/model/server/firewall.dart';

extension UfwActionX on UfwAction {
  Color get color => switch (this) {
    UfwAction.allow => Colors.green,
    UfwAction.deny => Colors.red,
    UfwAction.reject => Colors.orange,
    UfwAction.limit => Colors.blue,
  };
}

extension UfwDirectionX on UfwDirection {
  /// The word ufw writes: `in`, `out`.
  String get token => ufwDirectionToken(direction: this);
}

extension UfwLogX on UfwLog {
  /// The word ufw writes: `log`, `log-all`.
  String get token => ufwLogToken(log: this);
}
