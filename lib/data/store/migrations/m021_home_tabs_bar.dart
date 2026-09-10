import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// Moves the last tab out of the five-button home bar used by older builds.
///
/// The setting used to contain every tab available to the home page. The
/// current setting contains only the tabs shown in the bar, with the rest
/// reached through "more", so the old five-item default has to be converted
/// once. A custom order is preserved; only the old set of five tabs is
/// recognized, which keeps this migration from changing a newer arrangement.
class HomeTabsBarMigration implements SchemaMigration {
  const HomeTabsBarMigration({SettingStore? store}) : _store = store;

  final SettingStore? _store;

  static const appliedAt = 21;
  static const key = 'homeTabs';
  static const legacyTabs = {
    AppTab.server,
    AppTab.ssh,
    AppTab.file,
    AppTab.snippet,
    AppTab.agent,
  };

  @override
  int get from => appliedAt;

  @override
  Future<void> apply() async => applySync();

  void applySync() {
    final store = _store ?? SettingStore.instance;
    final raw = store.get<Object>(key);
    if (raw is! List) return;

    final tabs = AppTab.parseAppTabsFromObj(raw);
    if (tabs.length != legacyTabs.length ||
        !tabs.toSet().containsAll(legacyTabs)) {
      return;
    }

    final ok = store.set(
      key,
      tabs.take(tabs.length - 1).map((tab) => tab.name).toList(),
      updateLastUpdateTsOnSet: false,
    );
    if (!ok) throw StateError('m021: writing "$key" failed');
  }
}
