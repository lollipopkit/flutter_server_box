import 'dart:async';

import 'package:toolbox/core/provider_base.dart';

import '../model/sftp/req.dart';

class SftpProvider extends ProviderBase {
  final List<SftpReqStatus> _status = [];
  List<SftpReqStatus> get status => _status;

  Iterable<SftpReqStatus> gets({int? id, String? fileName}) {
    Iterable<SftpReqStatus> found = [];
    if (id != null) {
      found = _status.where((e) => e.id == id);
    }
    if (fileName != null) {
      found = found.where((e) => e.req.localPath.split('/').last == fileName);
    }
    return found;
  }

  SftpReqStatus? get({int? id, String? name}) {
    final found = gets(id: id, fileName: name);
    if (found.isEmpty) return null;
    return found.first;
  }

  void add(SftpReq req, {Completer? completer}) {
    _status.add(SftpReqStatus(
      notifyListeners: notifyListeners,
      completer: completer,
      req: req,
    ));
  }
}
