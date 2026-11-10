import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show Skills;

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

  /// [dir]'s skill as an op carries it, null when it was removed;
  /// [SyncRecords.unread] while the skills cannot be read, and
  /// [SyncRecords.silent] for one that went with what was lost
  /// ([SyncRecorder.wasLost]): neither is a removal.
  static Object? read(String dir) {
    if (Skills.fingerprints == null) return SyncRecords.unread;
    final skill = Skills.export(dir);
    if (skill == null && SyncRecorder.wasLost(c, dir)) return SyncRecords.silent;
    return skill;
  }

  /// Puts the skills [ops] carry here, or removes them; each recorded at its
  /// op's stamp.
  static void install(List<({String c, String id, String h, Object? d})> ops) {
    for (final op in ops) {
      try {
        Skills.import(op.id, switch (op.d) {
          final Map d => d.cast<String, Object?>(),
          _ => null,
        });
        SyncRecorder.forgetLost(c, op.id);
        SyncRecorder.see(c, op.id, Skills.fingerprints?[op.id]);
        SyncRecorder.receiving(op.h, () => SyncRecorder.record(c, op.id));
      } catch (e, s) {
        Loggers.app.warning('Sync skipped skill ${op.id}', e, s);
      }
    }
  }
}
