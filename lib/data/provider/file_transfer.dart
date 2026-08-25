import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/file/transfer_status.dart';

part 'file_transfer.freezed.dart';
part 'file_transfer.g.dart';

@freezed
abstract class FileTransferState with _$FileTransferState {
  const factory FileTransferState({
    @Default(<FileTransferStatus>[]) List<FileTransferStatus> transfers,
    @Default(0) int revision,
  }) = _FileTransferState;
}

/// Every transfer this app has been asked to run, wherever its two ends are.
@Riverpod(keepAlive: true)
class FileTransferNotifier extends _$FileTransferNotifier {
  @override
  FileTransferState build() {
    return const FileTransferState();
  }

  FileTransferStatus? get(int id) {
    try {
      return state.transfers.singleWhere((element) => element.id == id);
    } catch (e) {
      return null;
    }
  }

  /// [completer] is answered when the transfer ends, with whether it finished.
  /// A cancellation removes the row, so a caller that read [get] alone could
  /// not tell one from a success.
  int add(FileTransfer job, {Completer<bool>? completer}) {
    final status = FileTransferStatus(
      notifyListeners: _notifyUpdated,
      completer: completer,
      job: job,
    );
    _setTransfers([...state.transfers, status]);
    return status.id;
  }

  void dispose() {
    for (final item in state.transfers) {
      item.dispose();
    }
    _setTransfers([]);
  }

  void cancel(int id) {
    final idx = state.transfers.indexWhere((e) => e.id == id);
    if (idx < 0 || idx >= state.transfers.length) {
      dprint('FileTransferNotifier.cancel: id $id not found');
      return;
    }
    final item = state.transfers[idx];
    item.dispose();
    final next = List<FileTransferStatus>.from(state.transfers)..removeAt(idx);
    _setTransfers(next);
  }

  void refreshTransferSpeeds() {
    final now = DateTime.now();
    var changed = false;
    for (final item in state.transfers) {
      changed = item.refreshSpeed(now) || changed;
    }
    if (changed) _notifyUpdated();
  }

  void _setTransfers(List<FileTransferStatus> transfers) {
    state = state.copyWith(transfers: transfers, revision: state.revision + 1);
  }

  void _notifyUpdated() {
    // FileTransferStatus is mutable, so bump revision to make updates
    // observable.
    state = state.copyWith(
      transfers: List<FileTransferStatus>.from(state.transfers),
      revision: state.revision + 1,
    );
  }
}
