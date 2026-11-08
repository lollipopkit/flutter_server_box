import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show Skills;
import 'package:server_box/data/store/sync_recorder.dart';

/// The Agent's skills, synced as records of their own (`skill`, by
/// directory): files and all, so one installed from a folder or a file
/// reaches a device that has neither.
abstract final class SyncSkills {
  static const c = 'skill';

  /// Stamps each skill installed, changed, switched or removed here since it
  /// was last seen. While the lock cannot be read, the skills it listed may
  /// be lost here, not removed by the user ([SyncRecorder.loseSeen]).
  static void stamp({bool notify = false}) {
    if (Skills.fingerprints case final now?) {
      SyncRecorder.stampChanged(c, now, notify: notify);
    } else {
      SyncRecorder.loseSeen(c);
    }
  }

  static bool _following = false;

  /// Sends a skill installed, switched or removed here as it happens.
  static void follow() {
    if (_following) return;
    _following = true;
    SyncRecorder.follow(Skills.changes, () => stamp(notify: true));
  }

  static Object? read(String dir) => Skills.export(dir);

  /// Puts the skills [ops] carry here, or removes them; each recorded at its
  /// op's stamp.
  static void install(List<({String c, String id, String h, Object? d})> ops) {
    for (final op in ops) {
      try {
        Skills.import(op.id, switch (op.d) {
          final Map d => d.cast<String, Object?>(),
          _ => null,
        });
        SyncRecorder.see(c, op.id, Skills.fingerprints?[op.id]);
        SyncRecorder.receiving(op.h, () => SyncRecorder.record(c, op.id));
      } catch (e, s) {
        Loggers.app.warning('Sync skipped skill ${op.id}', e, s);
      }
    }
  }
}
