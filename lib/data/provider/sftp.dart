import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/sftp/worker.dart';

class SftpProvider extends Provider {
  const SftpProvider._();
  static const instance = SftpProvider._();

  static final status = <SftpReqStatus>[].vn;

  static SftpReqStatus? get(int id) {
    return status.value.singleWhere((element) => element.id == id);
  }

  static int add(SftpReq req, {Completer? completer}) {
    final reqStat = SftpReqStatus(
      notifyListeners: status.notify,
      completer: completer,
      req: req,
    );
    status.value.add(reqStat);
    status.notify();
    return reqStat.id;
  }

  static void dispose() {
    for (final item in status.value) {
      item.dispose();
    }
    status.value.clear();
    status.notify();
  }

  static void cancel(int id) {
    final idx = status.value.indexWhere((e) => e.id == id);
    status.value[idx].dispose();
    status.value.removeAt(idx);
    status.notify();
  }
}
