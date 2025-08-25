import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/sftp/worker.dart';

part 'sftp.freezed.dart';
part 'sftp.g.dart';

@freezed
abstract class SftpState with _$SftpState {
  const factory SftpState({
    @Default(<SftpReqStatus>[]) List<SftpReqStatus> requests,
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
      notifyListeners: _notifyListeners,
      completer: completer,
      req: req,
    );
    state = state.copyWith(
      requests: [...state.requests, reqStat],
    );
    return reqStat.id;
  }

  void dispose() {
    for (final item in state.requests) {
      item.dispose();
    }
    state = state.copyWith(requests: []);
  }

  void cancel(int id) {
    final idx = state.requests.indexWhere((e) => e.id == id);
    if (idx < 0 || idx >= state.requests.length) {
      dprint('SftpProvider.cancel: id $id not found');
      return;
    }
    final item = state.requests[idx];
    item.dispose();
    final newRequests = List<SftpReqStatus>.from(state.requests)
      ..removeAt(idx);
    state = state.copyWith(requests: newRequests);
  }

  void _notifyListeners() {
    // Force state update to notify listeners
    state = state.copyWith();
  }
}
