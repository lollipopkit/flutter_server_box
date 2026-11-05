import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/server/sudo_error.dart';
import 'package:server_box/generated/l10n/l10n.dart';

/// `SudoPassword`: one sudo password per server for the session, shared by
/// every feature — asked for once, tried before asking again, and dropped
/// when sudo refuses it.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SudoPassword.forget('s');
  });

  late BuildContext ctx;
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox();
        },
      ),
    ),
  );

  /// sudo as a host whose password is [right]: no password is refused.
  Future<List<String?>> Function(String? password) sudo(
    String right,
    List<String?> tried,
  ) =>
      (password) async {
        tried.add(password);
        return [password == right ? 'ok' : 'refused'];
      };

  Future<void> type(WidgetTester tester, String password) async {
    await tester.pump();
    await tester.enterText(find.byType(TextField), password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('asked once, then answered from the session', (tester) async {
    await pump(tester);
    final tried = <String?>[];
    final first = SudoPassword.retry(
      ctx,
      's',
      attempt: sudo('pw', tried),
      rejected: (r) => r.single == 'refused',
    );
    await type(tester, 'pw');
    expect((await first)?.single, 'ok');
    expect(tried, [null, 'pw']);

    // Another feature on the same server: nothing asked.
    tried.clear();
    final second = await SudoPassword.retry(
      ctx,
      's',
      attempt: sudo('pw', tried),
      rejected: (r) => r.single == 'refused',
    );
    expect(second?.single, 'ok');
    expect(tried, [null, 'pw']);
    expect(find.byType(TextField), findsNothing);
    expect(SudoPassword.typed('s'), 'pw');
  });

  testWidgets('one sudo refuses is dropped, and a new one asked for', (
    tester,
  ) async {
    await pump(tester);
    SudoPassword.remember('s', 'old');
    final tried = <String?>[];
    final result = SudoPassword.retry(
      ctx,
      's',
      attempt: sudo('new', tried),
      rejected: (r) => r.single == 'refused',
    );
    await type(tester, 'new');
    expect((await result)?.single, 'ok');
    expect(tried, [null, 'old', 'new']);
    expect(SudoPassword.typed('s'), 'new');
  });

  testWidgets('declined: nothing kept, nothing run again', (tester) async {
    await pump(tester);
    final tried = <String?>[];
    final result = SudoPassword.retry(
      ctx,
      's',
      attempt: sudo('pw', tried),
      rejected: (r) => r.single == 'refused',
    );
    await tester.pump();
    Navigator.of(ctx, rootNavigator: true).pop();
    expect(await result, isNull);
    expect(tried, [null]);
    expect(SudoPassword.typed('s'), isNull);
  });

  group('retryOnRejected', () {
    /// sudo as a host whose password is [right], refusing by throwing.
    Future<String> Function(String? password) throwing(
      String right,
      List<String?> tried,
    ) =>
        (password) async {
          tried.add(password);
          if (password != right) throw const SudoRejected();
          return 'ok';
        };

    testWidgets('a refusal moves on to the asked one', (tester) async {
      await pump(tester);
      final tried = <String?>[];
      final result = SudoPassword.retryOnRejected(
        ctx,
        's',
        attempt: throwing('pw', tried),
      );
      await type(tester, 'pw');
      expect(await result, 'ok');
      expect(tried, [null, 'pw']);
      expect(SudoPassword.typed('s'), 'pw');
    });

    testWidgets('refused after asking: rethrown, and forgotten', (
      tester,
    ) async {
      await pump(tester);
      final tried = <String?>[];
      final result = SudoPassword.retryOnRejected(
        ctx,
        's',
        attempt: throwing('right', tried),
      );
      final refused = expectLater(result, throwsA(isA<SudoRejected>()));
      await type(tester, 'wrong');
      await refused;
      expect(tried, [null, 'wrong']);
      expect(SudoPassword.typed('s'), isNull);
    });

    testWidgets('any other failure propagates without asking', (tester) async {
      await pump(tester);
      var tried = 0;
      final result = SudoPassword.retryOnRejected<String>(
        ctx,
        's',
        attempt: (_) async {
          tried++;
          throw StateError('disk gone');
        },
      );
      await expectLater(result, throwsA(isA<StateError>()));
      await tester.pump();
      expect(tried, 1);
      expect(find.byType(TextField), findsNothing);
    });
  });

  test('the one saved with the server is tried when none was typed', () async {
    FlutterSecureStorage.setMockInitialValues({'sudo_pwd_s': 'saved'});
    expect(await SudoPassword.known('s'), 'saved');
    SudoPassword.remember('s', 'typed');
    expect(await SudoPassword.known('s'), 'typed');
    // What runs unasked uses only the typed one.
    SudoPassword.forget('s');
    expect(SudoPassword.typed('s'), isNull);
  });
}
