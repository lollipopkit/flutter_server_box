import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show RequestOptions, Response;
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/service/report_filter.dart';
import 'package:server_box/core/sync/failure.dart';
import 'package:server_box/core/sync/file_log.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

import '../helpers/sync_key.dart';

const _davPropOk = '''<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/dav/lpkt-apps/</D:href>
    <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
    <D:status>HTTP/1.1 200 OK</D:status></D:propstat>
  </D:response>
</D:multistatus>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docDir;
  late HttpServer server;
  Completer<void>? hangProbe;

  setUpAll(() async {
    await FlRust.ensureInitialized();
    docDir = await Directory.systemTemp.createTemp('sbm-webdav-ux-');
    Paths.doc = docDir.path;
    Paths.bakName = Miscs.bakFileName;
    Paths.bak = docDir.path.joinPath(Miscs.bakFileName);
  });

  tearDownAll(() async {
    if (docDir.existsSync()) {
      await docDir.delete(recursive: true);
    }
  });

  setUp(() async {
    HttpOverrides.global = null;
    hangProbe = null;
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: 'backup-secret-pass',
    });
    SqliteDb.openInMemory();
    await Stores.init();
    SyncRecorder.resetForTest();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain<void>();
      if (req.uri.path.startsWith('/hang/')) {
        await (hangProbe?.future ?? Future<void>.value());
      }
      final res = req.response;
      res.headers.set(HttpHeaders.connectionHeader, 'close');
      if (req.uri.path.startsWith('/dav/')) {
        if (req.method == 'PROPFIND') {
          if (req.uri.path.endsWith('/')) {
            res.statusCode = 207;
            res.headers.contentType = ContentType('application', 'xml');
            res.write(_davPropOk);
          } else {
            res.statusCode = HttpStatus.notFound;
          }
        } else if (req.method == 'PUT' || req.method == 'MKCOL') {
          res.statusCode = HttpStatus.created;
        } else {
          res.statusCode = HttpStatus.ok;
        }
      } else {
        // Reproduces #1995: root path answers OPTIONS with 200 but rejects PROPFIND/PUT with 405.
        if (req.method == 'OPTIONS') {
          res.statusCode = HttpStatus.ok;
        } else {
          res.statusCode = HttpStatus.methodNotAllowed;
          res.headers.contentType = ContentType.html;
          res.write('<html><body>405 Method Not Allowed</body></html>');
        }
      }
      try {
        await res.close();
      } catch (_) {}
    });
  });

  tearDown(() async {
    if (hangProbe != null && !hangProbe!.isCompleted) {
      hangProbe!.complete();
    }
    await server.close(force: true);
    await PrefProps.webdavSync.set(false);
    await PrefProps.icloudSync.set(false);
    BakSyncer.beforeForgetCheckpointForTest = null;
    await BakSyncer.forgetCheckpoint();
    bakSync.forgetInheritForTest();
    bakSync.lastFailure.value = null;
    fileLog.reset();
    BakSyncer.keyForTest = null;
    SyncKeyring.resetForTest();
    SyncKeyring.init(label: 'ServerBox sync key');
    SyncRecorder.resetForTest();
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> pumpAnim(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Interleaves real I/O (HttpServer / Rust FFI / File) with FakeAsync frames
  /// until [predicate] holds or [timeout] elapses.
  Future<void> waitUntil(
    WidgetTester tester,
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!predicate() && DateTime.now().isBefore(end)) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await pumpAnim(tester);
  }

  Future<void> pumpSyncPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [...app_locale.appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const Scaffold(body: BackupPage(section: BackupSection.sync));
            },
          ),
        ),
      ),
    );
    await pumpAnim(tester);
  }

  test('syncFailureText and ReportFilter handle WebdavException and SyncError(remote)', () {
    final resp = Response<String>(
      requestOptions: RequestOptions(path: '/lpkt-apps/'),
      statusCode: 405,
      statusMessage: 'Method Not Allowed',
      data: '<html><body>giant html error page</body></html>',
    );
    final err = WebdavException<String>(
      message: 'WebDAV operation failed',
      statusCode: 405,
      statusMessage: 'Method Not Allowed',
      response: resp,
    );
    final text = syncFailureText(err);
    expect(text, '405 Method Not Allowed · WebDAV operation failed');
    expect(text, isNot(contains('<html>')));
    expect(ReportFilter.isDefect(err), isFalse);

    const wrapped = SyncError(
      SyncEngineErrorKind.remote,
      '405 Method Not Allowed · WebDAV operation failed',
    );
    expect(syncFailureText(wrapped), '405 Method Not Allowed · WebDAV operation failed');
    expect(ReportFilter.isDefect(wrapped), isFalse);
  });

  testWidgets('wedged bad WebDAV URL can be edited with preserved focus and removed from Manual row', (tester) async {
    final badUrl = 'http://127.0.0.1:${server.port}/';
    final goodUrl = 'http://127.0.0.1:${server.port}/dav/';
    SyncRemotes.setWebdav(url: badUrl, user: 'alice', pwd: 'secret');

    await pumpSyncPage(tester);

    // Even when channel is Off, Manual exposes the saved WebDAV URL as a tappable row.
    final manualSub = find.text('$badUrl · alice');
    expect(manualSub, findsOneWidget);

    await tester.tap(manualSub);
    await pumpAnim(tester);

    // Sheet opens with pre-filled values and obscured password field.
    expect(find.text(libL10n.save), findsOneWidget);
    expect(find.text(libL10n.delete), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.length, 3);
    expect(fields[0].controller?.text, badUrl);
    expect(fields[1].controller?.text, 'alice');
    expect(fields[2].controller?.text, 'secret');
    expect(fields[2].obscureText, isTrue);

    // Saving the bad 405 URL keeps the sheet open with inline error and preserves input.
    await tester.tap(find.text(libL10n.save));
    await waitUntil(tester, () => find.textContaining('405').evaluate().isNotEmpty);

    expect(find.textContaining('405'), findsOneWidget);
    expect(find.text(libL10n.save), findsOneWidget);
    expect(fields[0].controller?.text, badUrl);

    // Focusing URL field and typing character-by-character dismisses the banner
    // WITHOUT dropping focus from the URL field.
    final urlFieldFinder = find.byKey(const ValueKey('webdav_url_input'));
    await tester.tap(urlFieldFinder);
    await tester.pump();
    final urlFocusBefore = tester.widget<TextField>(find.descendant(of: urlFieldFinder, matching: find.byType(TextField))).focusNode!;
    expect(urlFocusBefore.hasFocus, isTrue);

    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '${badUrl}d',
        selection: TextSelection.collapsed(offset: badUrl.length + 1),
      ),
    );
    await tester.pump();
    expect(find.textContaining('405'), findsNothing);
    expect(urlFocusBefore.hasFocus, isTrue);

    // Complete the valid /dav/ URL and save.
    await tester.enterText(find.byType(TextField).at(0), goodUrl);
    await tester.pump();
    await tester.tap(find.text(libL10n.save));
    await waitUntil(
      tester,
      () => SyncRemotes.webdavUrl == goodUrl && find.byKey(const ValueKey('webdav_url_input')).evaluate().isEmpty,
    );

    expect(SyncRemotes.webdavUrl, goodUrl);
    expect(find.text('$goodUrl · alice'), findsOneWidget);

    // Re-open editor by tapping the Manual row and remove the saved WebDAV config.
    await tester.tap(find.text('$goodUrl · alice'));
    await pumpAnim(tester);
    await tester.tap(find.text(libL10n.delete));
    await pumpAnim(tester);

    expect(find.text(AppLocalizationsEn().webdavRemoveConfirm), findsOneWidget);
    await tester.tap(find.text(libL10n.ok));
    await waitUntil(
      tester,
      () => !SyncRemotes.hasWebdav && find.byKey(const ValueKey('webdav_url_input')).evaluate().isEmpty,
    );

    expect(SyncRemotes.hasWebdav, isFalse);
    expect(find.text('$goodUrl · alice'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real fileLog.keyOf 405 failure surfaces clean Edit recovery loop and activates after fix', (tester) async {
    final badUrl = 'http://127.0.0.1:${server.port}/';
    final goodUrl = 'http://127.0.0.1:${server.port}/dav/';
    SyncRemotes.setWebdav(url: badUrl, user: 'alice', pwd: 'secret');
    // Do NOT stub BakSyncer.keyForTest: exercise the real fileLog.keyOf -> syncReply -> Rust path.

    await pumpSyncPage(tester);

    await tester.tap(find.text(AppLocalizationsEn().syncChannel));
    await pumpAnim(tester);
    await tester.tap(find.text('WebDAV').last);
    await waitUntil(tester, () => find.text(AppLocalizationsEn().syncStateFailed).evaluate().isNotEmpty);

    // Failure sheet displays concise 405 error without "Sync host:" or HTML dump.
    expect(find.text(AppLocalizationsEn().syncStateFailed), findsOneWidget);
    expect(find.textContaining('405'), findsOneWidget);
    expect(find.textContaining('Sync host:'), findsNothing);
    expect(find.textContaining('<html>'), findsNothing);
    expect(find.text(libL10n.edit), findsOneWidget);
    expect(ReportFilter.isDefect(bakSync.lastFailure.value!), isFalse);

    // Tapping Edit opens the pre-filled WebDAV editor with inline error.
    await tester.tap(find.text(libL10n.edit));
    await pumpAnim(tester);
    await pumpAnim(tester);

    expect(find.text(libL10n.save), findsOneWidget);
    expect(find.textContaining('405'), findsOneWidget);
    final urlField = tester.widgetList<TextField>(find.byType(TextField)).first;
    expect(urlField.controller?.text, badUrl);

    // Fix URL to /dav/ and verify automatic retry enables WebDAV.
    final keyHandle = (await tester.runAsync(() => keyOf(MemoryKeyFile('webdav-recover'))))!;
    BakSyncer.keyForTest = (_) async => keyHandle;
    await tester.enterText(find.byType(TextField).at(0), goodUrl);
    await tester.pump();
    await tester.tap(find.text(libL10n.save));
    await waitUntil(tester, () => PrefProps.webdavSync.get());

    expect(SyncRemotes.webdavUrl, goodUrl);
    expect(bakSync.lastFailure.value, isNull);
    expect(PrefProps.webdavSync.get(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('upload error thrown by bakSync.sync still enters Edit recovery loop and rolls back on cancel', (tester) async {
    final badUrl = 'http://127.0.0.1:${server.port}/';
    SyncRemotes.setWebdav(url: badUrl, user: 'alice', pwd: 'secret');
    final keyHandle = (await tester.runAsync(() => keyOf(MemoryKeyFile('webdav-upload-err'))))!;
    // Key check succeeds, then backup upload PUT hits 405 on the root path and throws.
    BakSyncer.keyForTest = (_) async => keyHandle;

    await pumpSyncPage(tester);

    await tester.tap(find.text(AppLocalizationsEn().syncChannel));
    await pumpAnim(tester);
    await tester.tap(find.text('WebDAV').last);
    await waitUntil(tester, () => find.text(AppLocalizationsEn().syncStateFailed).evaluate().isNotEmpty);

    expect(find.text(AppLocalizationsEn().syncStateFailed), findsOneWidget);
    expect(find.text(libL10n.edit), findsOneWidget);
    await tester.tap(find.text(libL10n.close));
    await pumpAnim(tester);

    // Giving up rolls back the trial failure so global sync state is not polluted.
    expect(PrefProps.webdavSync.get(), isFalse);
    expect(bakSync.lastFailure.value, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Cancel button aborts an in-flight WebDAV probe without saving', (tester) async {
    hangProbe = Completer<void>();
    final hangUrl = 'http://127.0.0.1:${server.port}/hang/';

    await pumpSyncPage(tester);

    await tester.tap(find.text(AppLocalizationsEn().syncChannel));
    await pumpAnim(tester);
    await tester.tap(find.text('WebDAV'));
    await pumpAnim(tester);

    await tester.enterText(find.byType(TextField).at(0), hangUrl);
    await tester.pump();
    await tester.tap(find.text(libL10n.save));
    await tester.pump();

    // While probe is hanging, Cancel remains enabled and dismisses immediately.
    await tester.tap(find.text(libL10n.cancel));
    await pumpAnim(tester);
    hangProbe!.complete();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text(libL10n.save), findsNothing);
    expect(SyncRemotes.hasWebdav, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('active WebDAV failure status row opens editor and delete disables auto sync', (tester) async {
    final goodUrl = 'http://127.0.0.1:${server.port}/dav/';
    SyncRemotes.setWebdav(url: goodUrl, user: 'alice', pwd: 'secret');
    await PrefProps.webdavSync.set(true);

    bakSync.lastFailure.value = WebdavException<String>(
      message: 'Authentication required',
      statusCode: 401,
      statusMessage: 'Unauthorized',
    );

    await pumpSyncPage(tester);

    expect(find.text(AppLocalizationsEn().syncStateFailed), findsOneWidget);
    expect(find.text('401 Unauthorized · Authentication required'), findsOneWidget);

    // Tapping the failure status row opens the WebDAV settings sheet with the error.
    await tester.tap(find.text(AppLocalizationsEn().syncStateFailed));
    await pumpAnim(tester);

    expect(find.text(libL10n.save), findsOneWidget);
    expect(find.text(libL10n.delete), findsOneWidget);

    // Deleting while active asks with active confirmation and turns off auto sync.
    await tester.tap(find.text(libL10n.delete));
    await pumpAnim(tester);
    expect(find.text(AppLocalizationsEn().webdavRemoveActiveConfirm), findsOneWidget);

    await tester.tap(find.text(libL10n.ok));
    await waitUntil(tester, () => !SyncRemotes.hasWebdav && !PrefProps.webdavSync.get());

    expect(SyncRemotes.hasWebdav, isFalse);
    expect(PrefProps.webdavSync.get(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('invalid URL shows inline error without closing sheet or saving', (tester) async {
    await pumpSyncPage(tester);

    await tester.tap(find.text(AppLocalizationsEn().syncChannel));
    await pumpAnim(tester);
    await tester.tap(find.text('WebDAV'));
    await pumpAnim(tester);

    await tester.enterText(find.byType(TextField).at(0), 'not-a-valid-url');
    await tester.tap(find.text(libL10n.save));
    await pumpAnim(tester);

    expect(find.text(libL10n.invalidUrl), findsOneWidget);
    expect(find.text(libL10n.save), findsOneWidget);
    expect(SyncRemotes.hasWebdav, isFalse);

    await tester.tap(find.text(libL10n.cancel));
    await pumpAnim(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dismissing sheet during post-save cleanup still waits and returns saved outcome', (tester) async {
    final badUrl = 'http://127.0.0.1:${server.port}/';
    final goodUrl = 'http://127.0.0.1:${server.port}/dav/';
    SyncRemotes.setWebdav(url: badUrl, user: 'alice', pwd: 'secret');
    final keyHandle = (await tester.runAsync(() => keyOf(MemoryKeyFile('webdav-commit-dismiss'))))!;
    BakSyncer.keyForTest = (_) async => keyHandle;

    await pumpSyncPage(tester);

    // Trigger 405 failure when switching channel to WebDAV, then tap Edit.
    await tester.tap(find.text(AppLocalizationsEn().syncChannel));
    await pumpAnim(tester);
    await tester.tap(find.text('WebDAV').last);
    await waitUntil(tester, () => find.text(AppLocalizationsEn().syncStateFailed).evaluate().isNotEmpty);

    await tester.tap(find.text(libL10n.edit));
    await pumpAnim(tester);
    await pumpAnim(tester);

    final enteredCommit = Completer<void>();
    final releaseCommit = Completer<void>();
    BakSyncer.beforeForgetCheckpointForTest = () async {
      if (!enteredCommit.isCompleted) enteredCommit.complete();
      await releaseCommit.future;
    };

    await tester.enterText(find.byType(TextField).at(0), goodUrl);
    await tester.pump();
    await tester.tap(find.text(libL10n.save));

    await waitUntil(tester, () => enteredCommit.isCompleted);

    // Settings have already been saved; Cancel must now be disabled during commit.
    expect(SyncRemotes.webdavUrl, goodUrl);
    final cancelBtn = tester.widget<TextButton>(
      find.ancestor(of: find.text(libL10n.cancel), matching: find.byType(TextButton)),
    );
    expect(cancelBtn.onPressed, isNull);

    // PopScope blocks scrim dismissal while commit cleanup is in flight.
    await tester.tapAt(const Offset(10, 10));
    await pumpAnim(tester);
    expect(find.byKey(const ValueKey('webdav_url_input')), findsOneWidget);

    // Even if the sheet is closed externally mid-commit (bypassing PopScope),
    // the caller waits for cleanup and receives the saved outcome rather than null.
    SheetX.frontSheet!.close();
    await pumpAnim(tester);
    expect(find.byKey(const ValueKey('webdav_url_input')), findsNothing);
    expect(PrefProps.webdavSync.get(), isFalse);

    releaseCommit.complete();
    await waitUntil(tester, () => PrefProps.webdavSync.get());

    expect(PrefProps.webdavSync.get(), isTrue);
    expect(bakSync.lastFailure.value, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
