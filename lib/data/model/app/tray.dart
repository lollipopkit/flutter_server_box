import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/server.dart';

/// What one server looks like in the tray menu.
///
/// A plain row of text, and deliberately so. A native menu draws what it is
/// given: macOS would take an image per item, Windows wants owner-drawn menus
/// for anything but a checkmark, and GTK wants a widget — three ways to say the
/// same small thing, none of them shared. A glyph in the label reads the same
/// on all three and needs no per-platform code at all.
enum TrayLineState {
  /// Connected, and the machine answered.
  ok('●'),

  /// On its way: connecting, or a status still being read.
  working('◐'),

  /// Not connected, and nothing went wrong — a server nobody has opened yet,
  /// or one disconnected by hand.
  offline('○'),

  /// Tried and could not.
  failed('✕');

  const TrayLineState(this.glyph);

  /// Drawn before the name. Chosen from what a menu font can be relied on to
  /// have: these four are in every system UI font on the three platforms.
  final String glyph;
}

/// Which of the four a connection reads as.
///
/// [ServerConn.finished] and [ServerConn.connected] both mean the machine is
/// there; the difference between them is whether a status has been parsed yet,
/// which the detail column says.
TrayLineState trayStateOf(ServerConn conn) => switch (conn) {
  ServerConn.failed => TrayLineState.failed,
  ServerConn.disconnected => TrayLineState.offline,
  ServerConn.connecting || ServerConn.loading => TrayLineState.working,
  ServerConn.connected || ServerConn.finished => TrayLineState.ok,
};

/// The right-hand part of a row: what the machine is doing, or why there is
/// nothing to say about it.
///
/// Percentages rather than the absolute numbers for CPU, and both for memory —
/// "3.2G/8G" answers "is it nearly full" and "how big is it" at once, and the
/// second question is what tells two similar machines apart in a list.
String trayDetail({
  required ServerConn conn,
  double? cpuPercent,
  int? memUsedKib,
  int? memTotalKib,
}) {
  switch (trayStateOf(conn)) {
    case TrayLineState.failed:
      return libL10n.fail;
    case TrayLineState.offline:
      return libL10n.disconnected;
    case TrayLineState.working:
      // No word for it: there is no string in either catalogue for "on its
      // way", the glyph beside it already says so, and inventing one would be
      // twelve translations for a row that is on screen for a second.
      return '…';
    case TrayLineState.ok:
      break;
  }

  // Connected, but nothing has been read back yet — the first status of a
  // session, or one that returned nothing. Saying "0%" there would be a
  // measurement, and this is the absence of one.
  if (cpuPercent == null || memTotalKib == null || memTotalKib == 0) {
    return '--';
  }

  final cpu = '${cpuPercent.round()}%';
  return '$cpu  ${(memUsedKib ?? 0).kb2Str}/${memTotalKib.kb2Str}';
}

/// One row, and what a menu item is built from.
class TrayLine {
  const TrayLine({
    required this.id,
    required this.name,
    required this.detail,
    required this.state,
  });

  /// The server this row is about. Carried so that clicking the row can open
  /// it, which is the only reason the tray knows about ids at all.
  final String id;

  final String name;
  final String detail;
  final TrayLineState state;

  /// Two spaces after the glyph and four before the detail, which is as much
  /// alignment as a native menu allows: none of the three platforms lays out
  /// columns, and a proportional font makes padding to a width a guess that is
  /// wrong on the next machine.
  String get label => '${state.glyph}  $name    $detail';

  @override
  bool operator ==(Object other) =>
      other is TrayLine &&
      other.id == id &&
      other.name == name &&
      other.detail == detail &&
      other.state == state;

  @override
  int get hashCode => Object.hash(id, name, detail, state);

  @override
  String toString() => 'TrayLine($label)';
}

/// Everything the tray shows, as one value.
///
/// One value so that pushing it can be skipped when nothing changed. The menu
/// is rebuilt from scratch on every push — there is no API on any of the three
/// platforms for editing one item — and doing that at the poll rate would
/// rebuild a menu the user may have open.
class TrayModel {
  const TrayModel(this.lines);

  const TrayModel.empty() : lines = const [];

  final List<TrayLine> lines;

  /// Whether anything needs attention, which is what the icon says.
  ///
  /// Only [TrayLineState.failed]. A server nobody has connected yet is not a
  /// problem, and an icon that turned red for one would be red on most
  /// launches — which is how an alert stops being read.
  bool get alert => lines.any((l) => l.state == TrayLineState.failed);

  @override
  bool operator ==(Object other) =>
      other is TrayModel &&
      other.lines.length == lines.length &&
      _same(other.lines);

  bool _same(List<TrayLine> other) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(lines);
}
