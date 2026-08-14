import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/res/store.dart';

part 'agent_shell.g.dart';

/// How much of the Agent comes along onto the other tabs.
///
/// [hidden] is not "closed": the conversation is in `agentSessionProvider` and
/// carries on either way. This is only about whether there is a window onto it
/// while you are somewhere else.
enum AgentShellMode {
  hidden,
  collapsed,
  expanded;

  static AgentShellMode parse(String? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return AgentShellMode.hidden;
  }
}

@Riverpod(keepAlive: true)
class AgentShell extends _$AgentShell {
  @override
  AgentShellMode build() =>
      AgentShellMode.parse(Stores.setting.agentShellMode.fetch());

  /// Brings it back the way it was left, rather than always fully open: a user
  /// who collapsed it meant to keep it out of the way.
  void show() => _set(
    state == AgentShellMode.collapsed
        ? AgentShellMode.collapsed
        : AgentShellMode.expanded,
  );

  void expand() => _set(AgentShellMode.expanded);

  void collapse() => _set(AgentShellMode.collapsed);

  void hide() => _set(AgentShellMode.hidden);

  void toggle() => _set(
    state == AgentShellMode.hidden
        ? AgentShellMode.expanded
        : AgentShellMode.hidden,
  );

  void _set(AgentShellMode mode) {
    if (state == mode) return;
    state = mode;
    Stores.setting.agentShellMode.put(mode.name);
  }
}

/// Where the floating Agent was left.
///
/// Settings rather than provider state, for the same reason the pane divider's
/// width is: it is written continuously while a drag is in flight, and nothing
/// needs to rebuild in response — the widget doing the dragging already knows.
abstract final class AgentShellGeometry {
  /// The smallest the desktop panel may be dragged to. Below this the composer
  /// and the tool cards stop being usable rather than merely cramped.
  static const minSize = Size(320, 320);

  static const barHeight = 44.0;

  /// Room left between the panel and the window's edges.
  static const margin = 12.0;

  /// The top-left corner, or null when it has never been placed.
  static Offset? get offset {
    final left = Stores.setting.agentShellLeft.fetch();
    final top = Stores.setting.agentShellTop.fetch();
    if (left < 0 || top < 0) return null;
    return Offset(left, top);
  }

  static void saveOffset(Offset value) {
    Stores.setting.agentShellLeft.put(value.dx);
    Stores.setting.agentShellTop.put(value.dy);
  }

  static Size get size => Size(
    Stores.setting.agentShellWidth.fetch(),
    Stores.setting.agentShellHeight.fetch(),
  );

  static void saveSize(Size value) {
    Stores.setting.agentShellWidth.put(value.width);
    Stores.setting.agentShellHeight.put(value.height);
  }

  static bool get pillOnRight => Stores.setting.agentShellPillOnRight.fetch();

  static double get pillY => Stores.setting.agentShellPillY.fetch();

  static void savePill({required bool onRight, required double y}) {
    Stores.setting.agentShellPillOnRight.put(onRight);
    Stores.setting.agentShellPillY.put(y.clamp(0.0, 1.0));
  }

  static const minSheetFraction = 0.3;
  static const maxSheetFraction = 0.95;

  static double get sheetFraction => Stores.setting.agentShellSheetHeight
      .fetch()
      .clamp(minSheetFraction, maxSheetFraction);

  static void saveSheetFraction(double value) => Stores
      .setting
      .agentShellSheetHeight
      .put(value.clamp(minSheetFraction, maxSheetFraction));

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

    // Never placed: the bottom-right corner, furthest from the rail on the
    // left and the tab bar along the bottom.
    final placed =
        offset ??
        Offset(
          area.width - width - margin,
          area.height - bottomInset - height - margin,
        );
    final minTop = topInset + margin;
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
