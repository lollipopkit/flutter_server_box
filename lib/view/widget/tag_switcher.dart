import 'package:fl_lib/fl_lib.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';

/// The tag a list is filtered by, as the switcher of a [SwitcherBar]: "All"
/// or `#tag`, which of the tags it is, and the sheet of the others.
///
/// [onTap] null is a label rather than a way anywhere — for a list with no
/// tags and nothing to say about where they come from.
SessionSwitcherLabel tagSwitcherLabel({
  required List<String> tags,
  required String current,
  required VoidCallback? onTap,
}) {
  final at = tags.indexOf(current);
  return SessionSwitcherLabel(
    name: current.isEmpty ? libL10n.all : '#$current',
    // Counting from 1, and null on "all" — which is not one of the tags but
    // the absence of a choice among them, so it shows the icon instead.
    position: at < 0 ? null : at + 1,
    total: tags.length,
    icon: MingCute.hashtag_line,
    onTap: onTap,
  );
}

/// The tags, as rows. The same sheet the session switchers open, for the
/// same reason: a strip of them would be as wide as the names happened to be.
///
/// [emptyTip] says where tags come from, for a sheet that would otherwise be
/// one row saying "All" — which reads as a broken filter rather than as an
/// empty one.
Future<void> showTagSheet(
  BuildContext context, {
  required List<String> tags,
  required String current,
  required ValueChanged<String> onPick,
  String? emptyTip,
}) async {
  await showRowsSheet<void>(
    context,
    rows: (ctx) {
      void pick(String tag) {
        Navigator.of(ctx).pop();
        onPick(tag);
      }

      return [
        SheetChoiceTile(
          icon: MingCute.hashtag_line,
          title: libL10n.all,
          selected: current.isEmpty,
          onTap: () => pick(TagSwitcher.kDefaultTag),
        ),
        const Divider(height: 1),
        if (tags.isEmpty && emptyTip != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 27),
            child: Text(
              emptyTip,
              style: UIs.textGrey,
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final tag in tags)
            // The same shape as the row above it: the mark, then the name.
            // The mark is the `#`, so the name does not carry one as well.
            SheetChoiceTile(
              icon: MingCute.hashtag_line,
              title: tag,
              selected: tag == current,
              onTap: () => pick(tag),
            ),
      ];
    },
  );
}
