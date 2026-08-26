import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

/// Tells the user, once, that their hand-typed `/status` addresses stopped
/// working.
///
/// [LegacyStatusUrlsMigration] decides *whether* there is anything to say —
/// it is the only code that still sees the old configuration — and this is
/// what says it. The two are separate because a migration runs before there is
/// a screen to show anything on, and a message about a feature that has gone
/// must not be lost to whichever launch happened to run the migration.
///
/// Not a toast. A toast for this would be a sentence someone reads half of
/// while looking at something else, about a thing they will otherwise
/// rediscover as a broken widget days later.
abstract final class LegacyStatusNotice {
  static Future<void> showIfNeeded(BuildContext context) async {
    final pending = Stores.setting.legacyStatusNoticePending;
    if (!pending.fetch()) return;
    if (!context.mounted) return;

    await context.showRoundDialog(
      title: l10n.legacyStatusGoneTitle,
      child: SingleChildScrollView(
        child: SimpleMarkdown(data: l10n.legacyStatusGoneBody),
      ),
      actions: [Btn.ok()],
    );

    // Cleared after it has been seen through rather than when it was
    // scheduled, so a launch that never got as far as drawing this — killed in
    // the background, or dismissed by a route pushed over it — tries again.
    pending.put(false);
  }
}
