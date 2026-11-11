import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/card/title.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/spi_fixture.dart';

/// The card's one control, for an agent whose certificate has to be reviewed.
void main() {
  // The dialog formats the fingerprint in Rust.
  setUpAll(initRustLibForTest);

  const cert = CertInfo(
    fingerprint: 'ab12cd34ab12cd34ab12cd34ab12cd34ab12cd34ab12cd34ab12cd34ab12cd34',
    subject: '/CN=agent',
    issuer: '/CN=ca',
    notBefore: 1700000000,
    notAfter: 4000000000,
  );

  Future<void> pump(WidgetTester tester, Err err) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [...appLocalizationsDelegates],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ServerCardConnAction(
            srv: ServerState(
              spi: spiFixture(id: 'srv-1', name: 'pve', ip: 'h').copyWith(
                monitorHttp: const MonitorHttpCredential(addr: 'https://h:3770'),
              ),
              status: InitStatus.status..err = err,
              conn: ServerConn.failed,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a certificate to review is reviewed from the card', (tester) async {
    await pump(
      tester,
      const MonitorHttpErr(type: MonitorHttpErrType.certUnconfirmed, cert: cert),
    );

    expect(find.byIcon(Icons.refresh), findsNothing);
    await tester.tap(find.byIcon(Icons.verified_user_outlined));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().remoteDesktopTrustCertificate), findsOneWidget);
    expect(find.textContaining(cert.subject), findsOneWidget);
  });

  testWidgets('any other failure is asked again', (tester) async {
    await pump(tester, const MonitorHttpErr(type: MonitorHttpErrType.auth));

    expect(find.byIcon(Icons.verified_user_outlined), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
