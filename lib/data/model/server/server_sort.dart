import 'package:fl_lib/fl_lib.dart';

/// How the server list is ordered.
///
/// [manual] is the arrangement the user made on the settings page, which is
/// what `serverOrder` already is — so it sorts nothing, and is the default for
/// that reason. Anything else here is a view over that list, remembered but
/// never written back to it.
///
/// An enum rather than the two loose values it is stored as. The stored form
/// is an int and a bool, which is what the terminal tab's own sort keeps, and
/// everything above the store deals in one value.
enum ServerSortField {
  manual,
  name,
  status,

  /// Busiest first. The one an operator reaches for: a list ordered by how
  /// hard each machine is working puts the question at the top of it.
  cpu,

  /// Whatever is past its threshold, first. See `kServerAlertPercent` — the
  /// same line the card's footer and the overview's count mean by "over".
  alert,

  /// Shortest first, which is the direction that answers something: a machine
  /// that has just come back is news, and one up for two hundred days is not.
  uptime;

  /// The field a stored value names.
  ///
  /// Stored by name; the `Enum.index` this used to be is still read, because a
  /// device on an older build syncs the setting in that shape. An index means
  /// whatever this build's [values] order says, which is exactly the problem
  /// with keeping one.
  static ServerSortField fromStored(Object? stored) => switch (stored) {
    final String name =>
      values.firstWhereOrNull((field) => field.name == name) ?? manual,
    final int index when index >= 0 && index < values.length => values[index],
    _ => manual,
  };

  /// Whether reversing this field means anything.
  ///
  /// [manual] *is* the arrangement, so a reversed one is a second arrangement
  /// nobody made — and the list already has a page for saying what the order
  /// should be. [alert] is not a comparison either: it is "what is wrong,
  /// first", and its reverse is "what is wrong, last", which nobody wants.
  /// The rest are comparisons and read both ways.
  bool get directional => this != manual && this != alert;

  /// Whether ordering by this asks the machines anything.
  ///
  /// [manual] and [name] are answered by the record alone, so a page sorting
  /// by one of them does not have to watch every server's readings — which is
  /// a rebuild of the whole list on every poll.
  bool get readsStatus => this != manual && this != name;

  /// Whether the list may be dragged into a new order while this is on.
  ///
  /// Only [manual], because only [manual] is the order: dragging under a
  /// comparison would move a card and have the comparison put it straight
  /// back, which reads as the drag having failed.
  bool get reorderable => this == manual;
}
