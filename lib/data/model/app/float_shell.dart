import 'package:flutter/painting.dart';
import 'package:server_box/data/store/setting.dart';

/// How much of a floating panel comes along onto the other tabs.
///
/// [hidden] is not "closed": what the panel is a window onto — the Agent's
/// conversation, a terminal's shell — carries on either way. This is only
/// about whether there is a window onto it while you are somewhere else.
enum FloatShellMode {
  hidden,
  collapsed,
  expanded;

  static FloatShellMode parse(String? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return FloatShellMode.hidden;
  }
}

/// Where one floating panel was left.
///
/// Settings rather than provider state, for the same reason the pane divider's
/// width is: it is written continuously while a drag is in flight, and nothing
/// needs to rebuild in response — the widget doing the dragging already knows.
///
/// An instance per panel, bound to that panel's row, because two panels have
/// two positions. The arithmetic below is static: it is the same question
/// whichever panel is asking, and none of it reads the store.
final class FloatShellGeometry {
  const FloatShellGeometry(this._props, {required this.defaultCorner});

  final FloatShellProps _props;

  /// Which corner a panel that has never been placed starts in.
  ///
  /// Per panel because two of them can be on screen at once, and both starting
  /// in the same corner would put one exactly on top of the other — on a first
  /// run, which is the one time nobody has a placement to fall back on. Only
  /// the sign of each axis is read: a corner, not an arbitrary position.
  final Alignment defaultCorner;

  /// The smallest a desktop panel may be dragged to. Below this a conversation's
  /// composer and a terminal's columns stop being usable rather than merely
  /// cramped.
  static const minSize = Size(320, 320);

  static const barHeight = 44.0;

  /// Room left between the panel and the window's edges.
  static const margin = 12.0;

  /// The top-left corner, or null when it has never been placed.
  Offset? get offset {
    final left = _props.left.fetch();
    final top = _props.top.fetch();
    if (left < 0 || top < 0) return null;
    return Offset(left, top);
  }

  void saveOffset(Offset value) {
    _props.left.put(value.dx);
    _props.top.put(value.dy);
  }

  Size get size => Size(_props.width.fetch(), _props.height.fetch());

  void saveSize(Size value) {
    _props.width.put(value.width);
    _props.height.put(value.height);
  }

  bool get pillOnRight => _props.pillOnRight.fetch();

  double get pillY => _props.pillY.fetch();

  void savePill({required bool onRight, required double y}) {
    _props.pillOnRight.put(onRight);
    _props.pillY.put(y.clamp(0.0, 1.0));
  }

  static const minSheetFraction = 0.3;
  static const maxSheetFraction = 0.95;

  double get sheetFraction =>
      _props.sheetHeight.fetch().clamp(minSheetFraction, maxSheetFraction);

  void saveSheetFraction(double value) =>
      _props.sheetHeight.put(value.clamp(minSheetFraction, maxSheetFraction));

  /// How the panel was last left, for a caller that reopens it the way it was
  /// rather than always fully open.
  FloatShellMode get storedMode => FloatShellMode.parse(_props.mode.fetch());

  void saveMode(FloatShellMode mode) => _props.mode.put(mode.name);

  /// Where the desktop panel goes, given the window it has to fit inside.
  ///
  /// Pure, and separate from the widget, because this is the part that has to
  /// keep working when the inputs are hostile: a window narrower than
  /// [minSize], a saved position from a larger monitor, a panel taller than
  /// the screen it is being restored onto. Upper bounds are floored against
  /// their own lower bounds throughout — `clamp` throws when they cross, and
  /// every one of those cases crosses them.
  static Rect desktopRect({
    required Size area,
    required double topInset,
    required double bottomInset,
    required Offset? offset,
    required Size size,
    required bool collapsed,
    Alignment corner = Alignment.bottomRight,
  }) {
    final maxWidth = _atLeast(area.width - margin * 2, minSize.width);
    final maxHeight = _atLeast(
      area.height - topInset - bottomInset - margin * 2,
      minSize.height,
    );
    final width = size.width.clamp(minSize.width, maxWidth);
    final height = collapsed
        ? barHeight
        : size.height.clamp(minSize.height, maxHeight);

    final minTop = topInset + margin;
    // Never placed: whichever corner this panel calls its own. The default is
    // bottom-right, furthest from the rail on the left and the tab bar along
    // the bottom; a second panel is given another so the two do not start in
    // one place.
    final placed =
        offset ??
        Offset(
          corner.x < 0 ? margin : area.width - width - margin,
          corner.y < 0
              ? minTop
              : area.height - bottomInset - height - margin,
        );
    return Rect.fromLTWH(
      placed.dx.clamp(margin, _atLeast(area.width - width - margin, margin)),
      placed.dy.clamp(
        minTop,
        _atLeast(area.height - bottomInset - height - margin, minTop),
      ),
      width,
      height,
    );
  }

  /// How tall the phone panel is once the keyboard has taken its share.
  /// Without this the composer is pushed off the bottom the moment it is used.
  static double sheetHeightFor({
    required double areaHeight,
    required double topInset,
    required double keyboardInset,
    required double fraction,
  }) {
    const floor = 200.0;
    final available = _atLeast(
      areaHeight - keyboardInset - topInset - margin * 2,
      floor,
    );
    return (areaHeight * fraction).clamp(floor, available);
  }

  /// The top edge of the collapsed pill, from a 0..1 position down the screen.
  static double pillTopFor({
    required double areaHeight,
    required double topInset,
    required double bottomInset,
    required double y,
    required double pillSize,
  }) {
    final travel = _atLeast(
      areaHeight - topInset - bottomInset - pillSize - margin * 2,
      0,
    );
    return topInset + margin + travel * y.clamp(0.0, 1.0);
  }

  /// How far the pill can travel, which is also what a drag delta is measured
  /// against. Zero on a screen with no room, where the pill simply does not
  /// move rather than dividing by it.
  static double pillTravelFor({
    required double areaHeight,
    required double topInset,
    required double bottomInset,
    required double pillSize,
  }) {
    return _atLeast(
      areaHeight - topInset - bottomInset - pillSize - margin * 2,
      0,
    );
  }

  static double _atLeast(double value, double min) => value < min ? min : value;
}
