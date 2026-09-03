import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/generated/l10n/l10n.dart';

/// The three levels laid out, one sentence each.
///
/// Shared by the intro page and by **Settings → Privacy**, which is the point:
/// the two put the same question, and a level's sentence is the only place the
/// difference between them is written down. Kept apart they drifted — the
/// settings page had a picker dialog whose three rows were bare labels, so the
/// answer a user gave on the intro was one they could not re-read later.
///
/// A radio list rather than a switch, because three levels do not read as one,
/// and the middle level is the whole reason to offer a choice instead of an
/// on/off.
final class DiagnosticsLevelPicker extends StatelessWidget {
  /// Run after the new level is stored, for a caller that has to act on it.
  ///
  /// The store is written here because both callers write it identically. What
  /// happens next is not shared: the intro stores and does nothing, since
  /// nothing uploads until it is finished, while the settings page has to put
  /// the sink in or take it out at once.
  final VoidCallback? onPicked;

  const DiagnosticsLevelPicker({super.key, this.onPicked});

  @override
  Widget build(BuildContext context) {
    // Rebuilt on change so the selection is visible at once; the store is the
    // source of truth, not a field on this widget.
    return Stores.setting.diagnosticsLevel.listenable().listenVal((name) {
      // `RadioGroup` owns the selection — the per-tile `groupValue` and
      // `onChanged` are deprecated.
      return RadioGroup<DiagnosticsLevel>(
        groupValue: DiagnosticsLevel.fromName(name),
        onChanged: (level) {
          if (level == null) return;
          Stores.setting.diagnosticsLevel.put(level.name);
          onPicked?.call();
        },
        child: Column(
          // Reversed, so the list runs from most sent to least and the
          // recommended answer sits between the two it is a middle ground
          // between. The default is the quiet end — `none` on Android, which
          // is the only platform F-Droid distributes — so the case for
          // collecting has to be made here rather than by pre-selecting it.
          children: DiagnosticsLevel.values.reversed
              .map((e) => _tile(context, e))
              .toList(),
        ),
      );
    });
  }

  /// One level, with its own sentence saying what it sends.
  static Widget _tile(BuildContext ctx, DiagnosticsLevel level) {
    final (title, tip) = _levelText(ctx.l10n, level);
    return RadioListTile<DiagnosticsLevel>(
      value: level,
      title: level == kRecommendedLevel
          ? Row(
              children: [
                Flexible(child: Text(title)),
                UIs.width7,
                Text(
                  // The word this app already has. Its key names where it was
                  // first needed, not what it means.
                  ctx.l10n.sshKeyRecommended,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
              ],
            )
          : Text(title),
      subtitle: SimpleMarkdown(data: tip),
    ).cardx;
  }

  /// Which level this argues for.
  ///
  /// `basic`, not `full`. It is what answers a crash report — the failure, the
  /// build it happened in and the crumbs leading to it — and it sends nothing
  /// at all while the app is behaving. `full` adds timings, which are worth
  /// having when a problem is that something is slow rather than that it
  /// broke; that is a real case and a narrow one, so it is offered rather
  /// than recommended.
  static const kRecommendedLevel = DiagnosticsLevel.basic;

  /// A level's label and the sentence under it.
  ///
  /// One switch rather than two parallel ones: the pair belongs together, and
  /// a case added to the enum should fail to compile here once.
  static (String, String) _levelText(AppLocalizations l10n, DiagnosticsLevel l) {
    return switch (l) {
      DiagnosticsLevel.none => (l10n.crashCollectNone, l10n.crashCollectNoneTip),
      DiagnosticsLevel.basic => (
        l10n.crashCollectBasic,
        l10n.crashCollectBasicTip,
      ),
      DiagnosticsLevel.full => (l10n.crashCollectFull, l10n.crashCollectFullTip),
    };
  }
}
