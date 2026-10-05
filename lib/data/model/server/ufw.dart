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

extension UfwSnapshotX on UfwSnapshot {
  /// Whether a new connection like [access] gets through; [active], [rules]
  /// and [incoming] stand in for this snapshot's own, to ask about a change
  /// before it is made.
  FirewallReach reach(
    FirewallAccess access, {
    bool? active,
    List<UfwRule>? rules,
    UfwPolicy? incoming,
  }) => ufwReach(
    snapshot: this,
    access: access,
    active: active,
    rules: rules,
    incoming: incoming,
  );

  /// [rules] with [added] put where ufw puts a new rule: first, or last.
  List<UfwRule> withRules(List<UfwRule> added, {required bool prepend}) =>
      ufwWithRules(snapshot: this, added: added, prepend: prepend);
}

extension UfwRuleDraftX on UfwRuleDraft {
  /// The rules ufw would add for this draft, a profile's ports from [apps].
  List<UfwRule> asRules(List<UfwApp> apps) =>
      ufwDraftRules(draft: this, apps: apps);
}
