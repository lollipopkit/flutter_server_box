import 'dart:isolate';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/model/sftp/worker.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';

import 'helpers/spi_fixture.dart';

final _spi = spiFixture(
  name: 'Jump host',
  ip: '192.0.2.1',
  port: 22,
  user: 'tester',
  id: 'jump-host',
);

final _spiWithPassword = spiFixture(
  name: 'Jump host',
  ip: '192.0.2.1',
  port: 22,
  user: 'tester',
  pwd: 'stored-password',
  id: 'jump-host-with-password',
);

void main() {
  setUp(() {
    app_locale.l10n = AppLocalizationsEn();
  });

  tearDown(KeyboardInteractiveAuth.resetForTesting);

  test('empty keyboard-interactive request needs no dialog', () {
    final result = KeyboardInteractiveAuth.handle(
      _spi,
      SSHUserInfoRequest('', '', const []),
    );

    expect(result, isEmpty);
  });

  test('uses the stored password for an explicit password prompt', () {
    final result = KeyboardInteractiveAuth.handle(
      _spiWithPassword,
      SSHUserInfoRequest(
        'Login',
        '',
        [SSHUserInfoPrompt('Password:', false)],
      ),
    );

    expect(result, ['stored-password']);
  });

  test('SFTP authentication messages can cross isolate boundaries', () async {
    final events = await Isolate.run(
      () => <Object>[
        SftpKeyboardInteractivePrompt(
          id: 1,
          spi: _spi,
          expiresAt: DateTime.now().add(
            KeyboardInteractiveAuth.promptTimeout,
          ),
          request: SSHUserInfoRequest(
            'OTP',
            'Enter a code',
            [SSHUserInfoPrompt('Code:', false)],
          ),
        ),
        SftpHostKeyPrompt(
          id: 2,
          info: HostKeyPromptInfo(
            spi: _spi,
            keyType: 'ssh-ed25519',
            fingerprintHex: '00:11',
            fingerprintBase64: 'ABCD',
            isMismatch: false,
          ),
        ),
      ],
    );

    expect(events, hasLength(2));
    expect(events.first, isA<SftpKeyboardInteractivePrompt>());
    expect(events.last, isA<SftpHostKeyPrompt>());
  });

  testWidgets('collects every keyboard-interactive prompt response', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [LibLocalizations.delegate],
        supportedLocales: LibLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            ctx.setLibL10n();
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final resultFuture = KeyboardInteractiveAuth.handle(
      _spi,
      SSHUserInfoRequest(
        'Multi-factor authentication',
        'Enter all requested values.',
        [
          SSHUserInfoPrompt('Password:', false),
          SSHUserInfoPrompt('Verification code:', false),
          SSHUserInfoPrompt('Comment:', true),
        ],
      ),
      context: context,
    ) as Future<List<String>?>;

    await tester.pumpAndSettle();

    expect(find.text('Multi-factor authentication'), findsOneWidget);
    expect(find.text('Enter all requested values.'), findsOneWidget);
    expect(find.text('Server: Jump host'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    expect(tester.widget<TextField>(fields.at(0)).obscureText, isTrue);
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
    expect(tester.widget<TextField>(fields.at(2)).obscureText, isFalse);

    await tester.enterText(fields.at(0), 'secret');
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), 'trusted device');
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(
      await resultFuture,
      ['secret', '123456', 'trusted device'],
    );
  });

  testWidgets('hides a stored password prompt and asks only for OTP', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [LibLocalizations.delegate],
        supportedLocales: LibLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            ctx.setLibL10n();
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final resultFuture = KeyboardInteractiveAuth.handle(
      _spiWithPassword,
      SSHUserInfoRequest(
        'Multi-factor authentication',
        '',
        [
          SSHUserInfoPrompt('Password:', false),
          SSHUserInfoPrompt('Verification code:', false),
        ],
      ),
      context: context,
    ) as Future<List<String>?>;

    await tester.pumpAndSettle();

    expect(find.text('Password:'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.labelText,
      'Verification code',
    );
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(await resultFuture, ['stored-password', '123456']);
  });

  testWidgets('preserves prompt order when stored password is last', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [LibLocalizations.delegate],
        supportedLocales: LibLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            ctx.setLibL10n();
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final resultFuture = KeyboardInteractiveAuth.handle(
      _spiWithPassword,
      SSHUserInfoRequest(
        'Multi-factor authentication',
        '',
        [
          SSHUserInfoPrompt('Verification code:', false),
          SSHUserInfoPrompt('Password:', false),
        ],
      ),
      context: context,
    ) as Future<List<String>?>;

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(await resultFuture, ['123456', 'stored-password']);
  });

  testWidgets('keeps the original prompt as a standardized field hint', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [LibLocalizations.delegate],
        supportedLocales: LibLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            ctx.setLibL10n();
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final resultFuture = KeyboardInteractiveAuth.handle(
      _spi,
      SSHUserInfoRequest(
        'Multi-factor authentication',
        '',
        [SSHUserInfoPrompt('Enter backup code from list 3:', false)],
      ),
      context: context,
    ) as Future<List<String>?>;

    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.labelText, 'Verification code');
    expect(field.decoration?.hintText, 'Enter backup code from list 3:');
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(await resultFuture, isNull);
  });

  testWidgets('expires an unanswered authentication dialog', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [LibLocalizations.delegate],
        supportedLocales: LibLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            ctx.setLibL10n();
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final resultFuture = KeyboardInteractiveAuth.handle(
      _spi,
      SSHUserInfoRequest(
        'OTP',
        '',
        [SSHUserInfoPrompt('Verification code:', false)],
      ),
      context: context,
      timeout: const Duration(seconds: 1),
    ) as Future<List<String>?>;

    await tester.pumpAndSettle();
    expect(find.text('OTP'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(await resultFuture, isNull);
    expect(find.text('OTP'), findsNothing);
  });

  testWidgets('keeps a one-time password user-editable', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [LibLocalizations.delegate],
        supportedLocales: LibLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            ctx.setLibL10n();
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final resultFuture = KeyboardInteractiveAuth.handle(
      _spiWithPassword,
      SSHUserInfoRequest(
        'Multi-factor authentication',
        '',
        [SSHUserInfoPrompt('One-time password:', false)],
      ),
      context: context,
    ) as Future<List<String>?>;

    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.labelText,
      'Verification code',
    );
    await tester.enterText(find.byType(TextField), '654321');
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(await resultFuture, ['654321']);
  });

  testWidgets('localizes a verification-code prompt', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          LibLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            app_locale.l10n = AppLocalizations.of(ctx)!;
            ctx.setLibL10n();
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final resultFuture = KeyboardInteractiveAuth.handle(
      _spiWithPassword,
      SSHUserInfoRequest(
        'Multi-factor authentication',
        '',
        [SSHUserInfoPrompt('Verification code:', false)],
      ),
      context: context,
    ) as Future<List<String>?>;

    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.labelText,
      '验证码',
    );
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(await resultFuture, ['123456']);
  });

  testWidgets('cancelled response is not remembered', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [LibLocalizations.delegate],
        supportedLocales: LibLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            ctx.setLibL10n();
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final request = SSHUserInfoRequest(
      'OTP',
      '',
      [SSHUserInfoPrompt('Code:', false)],
    );
    final firstFuture = KeyboardInteractiveAuth.handle(
      _spi,
      request,
      context: context,
    ) as Future<List<String>?>;
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '654321');
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
    expect(await firstFuture, isNull);

    final secondFuture = KeyboardInteractiveAuth.handle(
      _spi,
      request,
      context: context,
    ) as Future<List<String>?>;
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
    expect(await secondFuture, isNull);
  });

  testWidgets('serializes concurrent authentication dialogs', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [LibLocalizations.delegate],
        supportedLocales: LibLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            ctx.setLibL10n();
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    Future<List<String>?> request(String title) =>
        KeyboardInteractiveAuth.handle(
              _spi,
              SSHUserInfoRequest(
                title,
                '',
                [SSHUserInfoPrompt('Code:', false)],
              ),
              context: context,
            )
            as Future<List<String>?>;

    final first = request('First challenge');
    final second = request('Second challenge');
    await tester.pumpAndSettle();

    expect(find.text('First challenge'), findsOneWidget);
    expect(find.text('Second challenge'), findsNothing);
    await tester.enterText(find.byType(TextField), '111111');
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(find.text('First challenge'), findsNothing);
    expect(find.text('Second challenge'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '222222');
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(await first, ['111111']);
    expect(await second, ['222222']);
  });
}
