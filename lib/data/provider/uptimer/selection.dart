import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/provider/server/selection.dart';

part 'selection.g.dart';

/// Which Uptimer monitor is open in the Status tab's two-pane detail host,
/// parallel to `serverSelectionProvider` and `bmcSelectionProvider`.
@Riverpod(keepAlive: true)
class UptimerSelection extends _$UptimerSelection {
  @override
  int? build() {
    ref.listen(serverSelectionProvider, (_, next) {
      if (next != null && state != null) state = null;
    });
    return null;
  }

  void select(int? id) => state = id;
}
