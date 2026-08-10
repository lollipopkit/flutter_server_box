import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selection.g.dart';

/// Which server the detail pane is showing.
///
/// State rather than a route argument, because in the two-pane layout it has
/// to outlive the pane's contents: the list highlights it, the pane renders
/// it, and a page pushed inside the pane replaces neither. In the single-pane
/// layout nothing reads it — there the pushed route still carries the answer,
/// which is why one call site can serve both.
///
/// Keyed the same way as `serverProvider`, so the two never disagree about
/// what identifies a server.
@Riverpod(keepAlive: true)
class ServerSelection extends _$ServerSelection {
  @override
  String? build() => null;

  void select(String? id) => state = id;

  /// Drops the selection when the selected server is gone, so the pane does
  /// not sit on a server that has been deleted.
  void clearIfMissing(Iterable<String> existing) {
    final current = state;
    if (current != null && !existing.contains(current)) state = null;
  }
}
