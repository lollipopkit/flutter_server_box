import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/widget/cert_sheet.dart';

/// Shows the certificate the agent presented and pins it if the user accepts.
///
/// Saving is the whole of it: `Spi.shouldReconnect` counts a changed
/// `monitorHttp`, so `updateServer` clears the retry limiter and refreshes on
/// its own.
Future<void> trustMonitorCert(
  BuildContext context,
  WidgetRef ref,
  ServerState srv,
  MonitorHttpErr err,
) async {
  final monitor = srv.spi.monitorHttp;
  final cert = err.cert;
  if (monitor == null || cert == null) return;
  final accepted = await showCertTrustSheet(
    context,
    cert: cert,
    previous: err.previousFingerprint,
  );
  if (!accepted || !context.mounted) return;
  try {
    await ref
        .read(serversProvider.notifier)
        .updateServer(srv.spi, srv.spi.copyWith(monitorHttp: monitor.withCertSha256(cert.fingerprint)));
  } catch (e, s) {
    if (context.mounted) context.showErrSheet(e, s);
  }
}
