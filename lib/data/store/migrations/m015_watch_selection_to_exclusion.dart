import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// Turns the watch's opt-in selection into an opt-out one.
///
/// The watch now shows every server with a `monitor` agent, so that adding a
/// server puts it on the watch without a second step. Left alone, that would
/// silently widen an existing setup: someone who picked two of their five
/// servers would find all five on their wrist, each with a freshly minted
/// credential, having asked for none of it.
///
/// So an explicit choice is carried over as its inverse — the three they did
/// not pick become the three held back. What they see afterwards is exactly
/// what they saw before, and the new default only applies to servers added
/// from here on.
///
/// An **empty** selection is left empty rather than treated as "exclude
/// everything". Empty is what an install that never opened the watch settings
/// looks like, and there is no way to tell it apart from a deliberate "none" —
/// but the two are not equally likely, and only one of them leaves the feature
/// off for someone who was never asked. Nothing is lost either way: the
/// exclusion list is one switch per server on the settings page.
///
/// TODO: drop together with `SettingStore.watchServerIds`.
class WatchSelectionToExclusionMigration implements SchemaMigration {
  const WatchSelectionToExclusionMigration();

  @override
  int get from => 15;

  @override
  Future<void> apply() async {
    final setting = SettingStore.instance;
    final selected = setting.watchServerIds.fetch();
    if (selected.isEmpty) return;

    // Read off the table rather than through `ServerStore`, which every
    // migration here does and this one has a second reason for: the store is a
    // singleton with a list cache, and a migration is exactly the moment when
    // what is cached and what is on disk are least likely to agree.
    //
    // Only servers that could have been picked. The selection could only ever
    // name a server with a monitor agent, and excluding an SSH-only one would
    // be a row of noise that means nothing — until that server gains an agent
    // one day and is mysteriously the only one missing.
    final excluded = SqliteDb.instance
        .select(
          'SELECT id FROM server '
          "WHERE monitor_addr IS NOT NULL AND trim(monitor_addr) != '' "
          'ORDER BY id;',
        )
        .map((row) => row['id'] as String)
        .where((id) => !selected.contains(id))
        .toList();

    // Written even when empty, so a rerun after an interrupted migration does
    // not read "nothing stored yet" and redo the work against a store that has
    // since changed.
    setting.watchExcludedServerIds.put(excluded);
  }
}
