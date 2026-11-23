import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/provider/server/selection.dart';

part 'selection.g.dart';

/// Which standalone BMC target is open in the Status tab's two-pane detail
/// host, parallel to `serverSelectionProvider`.
@Riverpod(keepAlive: true)
class BmcSelection extends _$BmcSelection {
  @override
  String? build() {
    ref.listen(serverSelectionProvider, (_, next) {
      if (next != null && state != null) state = null;
    });
    return null;
  }

  void select(String? id) => state = id;
}
