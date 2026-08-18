import 'package:flutter/widgets.dart';

/// The column beside the file tab's rail, for the things that used to push a
/// page over the whole window.
///
/// The transfers and the searches are all *about* what is in that column, and
/// a route drawn over everything covers the rail too — which is where someone
/// goes to get back, and what tells them which session they were on.
///
/// Absent when there is no second column: on a narrow window
/// [FilePaneHost.of] answers null and the caller pushes a page, which is the
/// behaviour those buttons have always had and the only one a phone can offer.
/// Absent outside the file tab as well — a browser opened as its own page has
/// no pane to lend.
class FilePaneHost extends InheritedWidget {
  const FilePaneHost({
    super.key,
    required this.open,
    required this.close,
    required super.child,
  });

  /// Shows [body] in the column.
  ///
  /// [body] draws its own bar, because what goes in it differs: the transfers
  /// want a title, and a search wants its field there beside the way back
  /// rather than a row of chrome above one.
  final void Function(WidgetBuilder body) open;

  /// Goes back to the browsers.
  ///
  /// Reachable from inside [body] as well as from the bar above it, because a
  /// search is finished by picking something rather than by closing it.
  final VoidCallback close;

  /// The host, or null where there is no second column to use.
  static FilePaneHost? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FilePaneHost>();

  @override
  bool updateShouldNotify(FilePaneHost oldWidget) => false;
}
