import 'package:server_box/core/chan.dart';

/// Deletes the copies `IncomingFiles` made of [paths] once [ends] are all
/// answered — at once when nothing was queued. What counts as a copy is
/// decided natively (`IncomingFiles.discardBatch`), never from these paths.
Future<void> discardIncomingAfter(
  List<String> paths,
  List<Future<bool>>? ends,
) async {
  if (ends != null) await Future.wait(ends);
  await MethodChans.discardIncoming(paths);
}
