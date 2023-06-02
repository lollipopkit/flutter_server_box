import 'dart:async';

import 'package:toolbox/core/provider_base.dart';

import '../model/sftp/req.dart';

class SftpProvider extends ProviderBase {
  final List<SftpReqStatus> _status = [];
  List<SftpReqStatus> get status => _status;

  List<SftpReqStatus> gets({int? id, String? fileName}) {
    var found = <SftpReqStatus>[];
    if (id != null) {
      found = _status.where((e) => e.id == id).toList();
    }
    if (fileName != null) {
      found = found
          .where((e) => e.item.localPath.split('/').last == fileName)
          .toList();
    }
    return found;
  }

  SftpReqStatus? get({int? id, String? name}) {
    final found = gets(id: id, fileName: name);
    if (found.isEmpty) return null;
    return found.first;
  }

  void add(SftpReqItem item, SftpReqType type, {Completer? completer}) {
    _status.add(SftpReqStatus(
      item: item,
      notifyListeners: notifyListeners,
      type: type,
      completer: completer,
    ));
  }
}
