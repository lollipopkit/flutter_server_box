import 'package:server_box/src/rust/api/bmc.dart';

extension BmcErrorX on BmcError {
  /// Safe to log and show: `detail` never carries a credential or a response
  /// body (`sbm_redfish::Error`).
  String get message =>
      detail == null ? failure.name : '${failure.name}: $detail';
}

extension CertInfoX on CertInfo {
  DateTime get startValidity =>
      DateTime.fromMillisecondsSinceEpoch(notBefore * 1000);
  DateTime get endValidity =>
      DateTime.fromMillisecondsSinceEpoch(notAfter * 1000);
}
