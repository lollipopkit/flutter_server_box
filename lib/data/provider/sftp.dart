import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/sftp/req.dart';
import 'package:server_box/data/model/sftp/status.dart';

part 'sftp.freezed.dart';
part 'sftp.g.dart';

@freezed
abstract class SftpState with _$SftpState {
  const factory SftpState({
    @Default(<SftpReqStatus>[]) List<SftpReqStatus> requests,
    @Default(0) int revision,
  }) = _SftpState;
}

@Riverpod(keepAlive: true)
class SftpNotifier extends _$SftpNotifier {
  @override
  SftpState build() {
    return const SftpState();
  }

  SftpReqStatus? get(int id) {
    try {
      return state.requests.singleWhere((element) => element.id == id);
    } catch (e) {
      return null;
    }
  }

  int add(SftpReq req, {Completer? completer}) {
    final reqStat = SftpReqStatus(
      notifyListeners: _notifyRequestUpdated,
      completer: completer,
      req: req,
    );
    _setRequests([...state.requests, reqStat]);
    return reqStat.id;
  }

  void dispose() {
    for (final item in state.requests) {
      item.dispose();
    }
    _setRequests([]);
  }

  void cancel(int id) {
    final idx = state.requests.indexWhere((e) => e.id == id);
    if (idx < 0 || idx >= state.requests.length) {
      dprint('SftpProvider.cancel: id $id not found');
      return;
    }
    final item = state.requests[idx];
    item.dispose();
    final newRequests = List<SftpReqStatus>.from(state.requests)..removeAt(idx);
    _setRequests(newRequests);
  }

  void refreshTransferSpeeds() {
    final now = DateTime.now();
    var changed = false;
    for (final item in state.requests) {
      changed = item.refreshSpeed(now) || changed;
    }
    if (changed) _notifyRequestUpdated();
  }

  void _setRequests(List<SftpReqStatus> requests) {
    state = state.copyWith(requests: requests, revision: state.revision + 1);
  }

  void _notifyRequestUpdated() {
    // SftpReqStatus is mutable, so bump revision to make updates observable.
    state = state.copyWith(
      requests: List<SftpReqStatus>.from(state.requests),
      revision: state.revision + 1,
    );
  }
}
