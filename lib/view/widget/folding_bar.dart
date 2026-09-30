import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// One icon button of a [FoldingBar].
final class BarAction {
  const BarAction({
    this.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.loading = false,
  });

  /// On the button while it is in the bar.
  final Key? key;
  final IconData icon;

  /// Its tooltip in the bar, its text in the menu.
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// A spinner in place of the icon, and no tap: for a refresh that is
  /// running, which is said where it was asked for rather than by a line
  /// somewhere else on the page.
  final bool loading;

  static const _spinner = SizedBox.square(
    dimension: 18,
    child: Padding(
      padding: EdgeInsets.all(1.5),
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  Widget buildIcon() => loading ? _spinner : Icon(icon, size: 18, color: color);
}

/// A bar's label and its icon buttons, in however much width the bar has.
///
/// The label keeps [labelMinWidth]; the buttons get the rest, as many as fit,
/// and those that do not are items of a menu behind a last button. So a
/// column dragged narrow shows what the bar is about and every action still,
/// rather than a label squeezed past its counter and chevron into an
/// overflow.
class FoldingBar extends StatelessWidget {
  const FoldingBar({
    super.key,
    required this.label,
    required this.actions,
    this.labelMinWidth = 104,
  });

  final Widget label;
  final List<BarAction> actions;

  /// Enough for a `SessionSwitcherLabel`'s counter, chevron and a few
  /// letters of its name.
  final double labelMinWidth;

  /// A `Btn.icon` of an 18pt icon: the icon and 7 of padding each side.
  static const slot = 18.0 + 7 * 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - labelMinWidth;
        final fits = room.isFinite ? (room / slot).floor() : actions.length;
        final folds = fits < actions.length;
        // The menu button takes one of the slots.
        final shown = folds ? actions.take(fits > 0 ? fits - 1 : 0) : actions;
        final folded = folds ? actions.skip(shown.length).toList() : const <BarAction>[];
        return Row(
          children: [
            Expanded(child: label),
            for (final a in shown)
              if (a.loading)
                // The slot a button takes, so the bar does not shift.
                Tooltip(
                  key: a.key,
                  message: a.label,
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: BarAction._spinner,
                  ),
                )
              else
                Btn.icon(
                  key: a.key,
                  text: a.label,
                  icon: Icon(a.icon, size: 18, color: a.color),
                  onTap: a.onTap,
                ),
            if (folded.isNotEmpty)
              ContextMenuButton(
                tooltip: libL10n.more,
                actions: () => [
                  for (final a in folded)
                    ContextMenuAction(
                      text: a.label,
                      icon: a.icon,
                      enabled: !a.loading,
                      onTap: a.onTap,
                    ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.more_vert, size: 18),
                ),
              ),
          ],
        );
      },
    );
  }
}
