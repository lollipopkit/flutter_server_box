/// Which drop targets a drag from another app is over right now.
///
/// On Android a drop's files are copied in before anything can read them
/// (`DropListener`), so the copy is made only where a target will take them:
/// the native side asks [accepting] before it starts.
abstract final class DropZones {
  static final _hovered = <Object>{};

  static bool get accepting => _hovered.isNotEmpty;

  static void enter(Object zone) => _hovered.add(zone);

  static void leave(Object zone) => _hovered.remove(zone);
}
