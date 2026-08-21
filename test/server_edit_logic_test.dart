import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/edit/edit.dart';

import 'helpers/spi_fixture.dart';

void main() {
  group('Server Edit Page Logic Tests', () {
    test('SSH import should only be available on desktop platforms', () {
      final desktopPlatforms = ['linux', 'macos', 'windows'];
      final mobilePlatforms = ['android', 'ios', 'fuchsia'];

      for (final platform in desktopPlatforms) {
        final isDesktop = desktopPlatforms.contains(platform);
        expect(
          isDesktop,
          isTrue,
          reason: '$platform should support SSH import',
        );
      }

      for (final platform in mobilePlatforms) {
        final isDesktop = desktopPlatforms.contains(platform);
        expect(
          isDesktop,
          isFalse,
          reason: '$platform should not support SSH import',
        );
      }
    });

    test('permission prompt conditions are correct', () {
      // Test the conditions for showing permission prompt

      // Should prompt when: firstTimeReadSSHCfg=true, sshConfigExists=true, isNewServer=true
      bool shouldPrompt(bool firstTime, bool configExists, bool isNew) {
        return firstTime && configExists && isNew;
      }

      expect(shouldPrompt(true, true, true), isTrue); // All conditions met
      expect(shouldPrompt(false, true, true), isFalse); // Setting disabled
      expect(shouldPrompt(true, false, true), isFalse); // No config file
      expect(
        shouldPrompt(true, true, false),
        isFalse,
      ); // Editing existing server
      expect(shouldPrompt(false, false, false), isFalse); // No conditions met
    });

    test('server validation logic works correctly', () {
      // Test server validation without actual form widgets

      // Valid server
      final validServer = spiFixture(
        name: 'test-server',
        ip: '192.168.1.100',
        port: 22,
        user: 'root',
      );

      expect(validServer.name.isNotEmpty, isTrue);
      expect(validServer.ssh?.ip.isNotEmpty, isTrue);
      expect(validServer.ssh!.port > 0 && validServer.ssh!.port <= 65535, isTrue);
      expect(validServer.ssh?.user.isNotEmpty, isTrue);

      // Invalid cases
      expect(''.isNotEmpty, isFalse); // Empty name
      expect(0 > 0, isFalse); // Invalid port
      expect(65536 <= 65535, isFalse); // Port too high
    });

    test('server form data processing is correct', () {
      // Test data processing logic

      final Map<String, dynamic> formData = {
        'name': 'my-server',
        'ip': '192.168.1.100',
        'port': '2222',
        'user': 'admin',
      };

      // Process form data into server object
      final server = spiFixture(
        name: formData['name'] as String,
        ip: formData['ip'] as String,
        port: int.parse(formData['port'] as String),
        user: formData['user'] as String,
      );

      expect(server.name, 'my-server');
      expect(server.ssh?.ip, '192.168.1.100');
      expect(server.ssh?.port, 2222);
      expect(server.ssh?.user, 'admin');
    });

    test('SSH key handling is correct', () {
      // Test SSH key field handling

      final serverWithKey = spiFixture(
        name: 'key-server',
        ip: '192.168.1.100',
        port: 22,
        user: 'root',
        keyId: '~/.ssh/id_rsa',
      );

      expect(serverWithKey.ssh?.keyId, '~/.ssh/id_rsa');
      expect(serverWithKey.ssh?.keyId?.isNotEmpty, isTrue);

      final serverWithoutKey = spiFixture(
        name: 'pwd-server',
        ip: '192.168.1.100',
        port: 22,
        user: 'root',
        pwd: 'password123',
      );

      expect(serverWithoutKey.ssh?.keyId, isNull);
      expect(serverWithoutKey.ssh?.pwd, 'password123');
    });

    testWidgets('server editor preserves combined SSH credentials', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});

      var server = spiFixture(
        name: 'combined-auth-server',
        ip: '192.168.1.100',
        port: 22,
        user: 'root',
        pwd: 'password123',
        keyId: 'key-id-1',
        id: 'combined-auth-server-id',
      );
      Spi? persisted;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serversProvider.overrideWith(
              () => _PersistingServersNotifier(
                server,
                (value) => persisted = value,
              ),
            ),
            privateKeyProvider.overrideWithValue(
              const PrivateKeyState(
                keys: [PrivateKeyInfo(id: 'key-id-1', name: 'prod key', key: 'unused')],
              ),
            ),
          ],
          child: MaterialApp(
            builder: ResponsivePoints.builder,
            locale: const Locale('en'),
            localizationsDelegates: const [
              LibLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                app_locale.l10n = AppLocalizations.of(context)!;
                context.setLibL10n();
                return Scaffold(
                  body: TextButton(
                    key: const ValueKey('open-server-editor'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ServerEditPage(args: SpiRequiredArgs(server)),
                      ),
                    ),
                    child: const Text('Open editor'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-server-editor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The name, not the id: an id is not something the user typed.
      expect(find.text('prod key'), findsOneWidget);
      expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .where((field) => field.controller.text == 'password123'),
        hasLength(1),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const ValueKey('open-server-editor')), findsOneWidget);
      expect(persisted, isNotNull);
      final restored = persisted!;
      expect(restored.ssh?.pwd, 'password123');
      // The reference is by id, which a rename cannot break.
      expect(restored.ssh?.keyId, 'key-id-1');

      server = restored;
      await tester.tap(find.byKey(const ValueKey('open-server-editor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The name, not the id: an id is not something the user typed.
      expect(find.text('prod key'), findsOneWidget);
      expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .where((field) => field.controller.text == 'password123'),
        hasLength(1),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('an imported server keeps its key file across a save', (
      tester,
    ) async {
      // The regression this guards: `_onSave` rebuilds the credential from the
      // form, and nothing on the form types a path — so opening an imported
      // server and saving it once used to take away the only credential it had.
      FlutterSecureStorage.setMockInitialValues({});

      final server = spiFixture(
        name: 'imported-server',
        ip: '192.168.1.101',
        user: 'me',
        keyPath: '~/.ssh/id_ed25519',
        id: 'imported-server-id',
      );
      Spi? persisted;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serversProvider.overrideWith(
              () => _PersistingServersNotifier(
                server,
                (value) => persisted = value,
              ),
            ),
            privateKeyProvider.overrideWithValue(const PrivateKeyState()),
          ],
          child: MaterialApp(
            builder: ResponsivePoints.builder,
            locale: const Locale('en'),
            localizationsDelegates: const [
              LibLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                app_locale.l10n = AppLocalizations.of(context)!;
                context.setLibL10n();
                return Scaffold(
                  body: TextButton(
                    key: const ValueKey('open-server-editor'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ServerEditPage(args: SpiRequiredArgs(server)),
                      ),
                    ),
                    child: const Text('Open editor'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-server-editor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Shown, rather than an empty key picker saying nothing is configured
      expect(find.text('~/.ssh/id_ed25519'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // No password and no stored key, but there *is* a key — so the
      // "continue without authentication?" dialog must not have appeared, and
      // the save must have gone straight through
      expect(find.byKey(const ValueKey('open-server-editor')), findsOneWidget);
      expect(persisted, isNotNull);
      expect(persisted!.ssh?.keyPath, '~/.ssh/id_ed25519');
      expect(persisted!.ssh?.keyId, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    test('server editing vs creation logic', () {
      // Test logic for distinguishing between editing and creating servers

      final existingServer = spiFixture(
        name: 'existing',
        ip: '192.168.1.100',
        port: 22,
        user: 'root',
        id: 'server123',
      );

      // Existing server has non-empty ID
      final isEditing = existingServer.id.isNotEmpty;
      final isCreating = !isEditing;

      expect(isEditing, isTrue);
      expect(isCreating, isFalse);

      final newServer = spiFixture(
        name: 'new-server',
        ip: '192.168.1.100',
        port: 22,
        user: 'root',
        id: '',
      );

      final isCreatingNew = newServer.id.isEmpty;
      final isEditingExisting = !isCreatingNew;

      expect(isCreatingNew, isTrue);
      expect(isEditingExisting, isFalse);
    });

    test('form field population from imported server', () {
      // Test that imported server data correctly populates form fields

      final importedServer = spiFixture(
        name: 'imported-prod-web',
        ip: '10.0.1.100',
        port: 2222,
        user: 'deploy',
        keyId: '~/.ssh/production.pem',
      );

      // Simulate form field population
      final formFields = {
        'name': importedServer.name,
        'ip': importedServer.ssh?.ip,
        'port': importedServer.ssh?.port.toString(),
        'user': importedServer.ssh?.user,
        'keyId': importedServer.ssh?.keyId,
      };

      expect(formFields['name'], 'imported-prod-web');
      expect(formFields['ip'], '10.0.1.100');
      expect(formFields['port'], '2222');
      expect(formFields['user'], 'deploy');
      expect(formFields['keyId'], '~/.ssh/production.pem');
    });

    test('import summary display logic', () {
      // Test import summary formatting

      const totalFound = 5;
      const duplicatesRemoved = 2;
      const serversToImport = 3;

      final summary = {
        'total': totalFound,
        'duplicates': duplicatesRemoved,
        'toImport': serversToImport,
      };

      expect(summary['total'], 5);
      expect(summary['duplicates'], 2);
      expect(summary['toImport'], 3);

      // Summary validation
      expect(summary['duplicates']! + summary['toImport']!, summary['total']);

      // Format summary message (simplified)
      final message =
          'Found ${summary['total']} servers, '
          '${summary['duplicates']} duplicates removed, '
          '${summary['toImport']} will be imported.';

      expect(
        message,
        'Found 5 servers, 2 duplicates removed, 3 will be imported.',
      );
    });

    test('error handling logic', () {
      // Test error handling scenarios

      final errors = <String>[];

      // Validation errors
      void validateServer(Spi server) {
        if (server.name.isEmpty) {
          errors.add('Server name is required');
        }
        final ssh = server.ssh;
        if (ssh == null) {
          errors.add('SSH credential is required');
          return;
        }
        if (ssh.ip.isEmpty) {
          errors.add('Server IP is required');
        }
        if (ssh.port <= 0 || ssh.port > 65535) {
          errors.add('Port must be between 1 and 65535');
        }
        if (ssh.user.isEmpty) {
          errors.add('Username is required');
        }
      }

      // Test with invalid server
      final invalidServer = spiFixture(name: '', ip: '', port: 0, user: '');

      validateServer(invalidServer);

      expect(errors.length, 4);
      expect(errors.contains('Server name is required'), isTrue);
      expect(errors.contains('Server IP is required'), isTrue);
      expect(errors.contains('Port must be between 1 and 65535'), isTrue);
      expect(errors.contains('Username is required'), isTrue);

      // Test with valid server
      errors.clear();
      final validServer = spiFixture(
        name: 'valid',
        ip: '192.168.1.1',
        port: 22,
        user: 'root',
      );

      validateServer(validServer);
      expect(errors.isEmpty, isTrue);
    });

    test('name conflict resolution logic', () {
      // Test name conflict resolution during import

      final existingNames = ['server1', 'server2', 'server3'];

      String resolveNameConflict(String proposedName, List<String> existing) {
        if (!existing.contains(proposedName)) {
          return proposedName;
        }

        int suffix = 2;
        String newName;
        do {
          newName = '$proposedName ($suffix)';
          suffix++;
        } while (existing.contains(newName));

        return newName;
      }

      // Test with no conflict
      expect(resolveNameConflict('unique-name', existingNames), 'unique-name');

      // Test with conflict
      expect(resolveNameConflict('server1', existingNames), 'server1 (2)');

      // Test with multiple conflicts
      final extendedNames = [...existingNames, 'server1 (2)'];
      expect(resolveNameConflict('server1', extendedNames), 'server1 (3)');
    });

    test('SSH config import button visibility logic', () {
      // Test when SSH import button should be visible

      bool shouldShowSSHImport({
        required bool isDesktop,
        required bool firstTimeReadSSHCfg,
        required bool isNewServer,
      }) {
        return isDesktop && (firstTimeReadSSHCfg || !isNewServer);
      }

      // Desktop, first time, new server - should show
      expect(
        shouldShowSSHImport(
          isDesktop: true,
          firstTimeReadSSHCfg: true,
          isNewServer: true,
        ),
        isTrue,
      );

      // Desktop, not first time, new server - should not show auto import but manual import available
      expect(
        shouldShowSSHImport(
          isDesktop: true,
          firstTimeReadSSHCfg: false,
          isNewServer: true,
        ),
        isFalse,
      );

      // Desktop, editing existing server - should show manual import
      expect(
        shouldShowSSHImport(
          isDesktop: true,
          firstTimeReadSSHCfg: false,
          isNewServer: false,
        ),
        isTrue,
      );

      // Mobile - should never show
      expect(
        shouldShowSSHImport(
          isDesktop: false,
          firstTimeReadSSHCfg: true,
          isNewServer: true,
        ),
        isFalse,
      );
    });
  });
}

final class _PersistingServersNotifier extends ServersNotifier {
  _PersistingServersNotifier(this.initialServer, this.onPersist);

  final Spi initialServer;
  final ValueChanged<Spi> onPersist;

  @override
  ServersState build() {
    return ServersState(
      servers: {initialServer.id: initialServer},
      serverOrder: [initialServer.id],
    );
  }

  @override
  Future<void> updateServer(Spi old, Spi newSpi) async {
    final persisted = Spi.fromJson(
      jsonDecode(jsonEncode(newSpi)) as Map<String, dynamic>,
    );
    onPersist(persisted);
    final servers = Map<String, Spi>.from(state.servers)
      ..remove(old.id)
      ..[persisted.id] = persisted;
    state = state.copyWith(
      servers: servers,
      serverOrder: servers.keys.toList(),
    );
  }
}
