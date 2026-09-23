/// Installing and updating from a repository, end to end through the page.
///
/// The model layer is checked elsewhere (`plugin_repo_test.dart`,
/// `plugin_store_merge_test.dart`). What only this can check is the order the
/// page does things in, and two of those are the whole integrity story:
///
/// - a package whose bytes are **not** the ones the repository described is
///   refused with nothing to answer, and nothing is installed;
/// - a package the repository named **no** checksum for is not installed until
///   the user has answered a dialog about it — and when that package is served
///   from somewhere else, not even fetched.
///
/// Neither shows up as an error anywhere else: the install succeeds either way
/// and the plugin works, so what would be lost is only the checking.
///
/// Build the native library first: cargo build -p sbm_ffi
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/repo.dart';
import 'package:server_box/data/model/plugin/repo_record.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/data/provider/plugin/repo_source.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;
import 'package:server_box/view/page/plugin/store.dart';

import 'helpers/plugin_sbp.dart';
import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';

/// The address a repository is added by, and the URL that turns into.
const _repoUrl = 'https://plugins.invalid/tap';
final _archiveUrl = PluginRepoSource.archiveUrlOf(_repoUrl);
const _elsewhere = 'https://packages.invalid';

/// Serves what a repository would, and records what was asked for.
///
/// The recording is load-bearing: "the dialog came before the download" is a
/// claim about what was requested and when, and there is nothing on screen that
/// says it.
class _FakeRepo implements HttpClientAdapter {
  final routes = <String, List<int>>{};
  final requested = <String>[];

  void serve(String url, List<int> bytes) => routes[url] = bytes;

  /// Serves a repository tree at [_archiveUrl], the way GitHub does: a gzipped
  /// tar with everything under one directory whose name the client cannot
  /// predict.
  void serveTree(Map<String, List<int>> files) {
    final archive = Archive();
    for (final e in files.entries) {
      archive.add(ArchiveFile.bytes('tap-0e1f2a3/${e.key}', e.value));
    }
    serve(
      _archiveUrl,
      GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive)),
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requested.add(url);
    final body = routes[url];
    if (body == null) return ResponseBody.fromString('no', 404);
    return ResponseBody.fromBytes(body, 200);
  }

  @override
  void close({bool force = false}) {}
}

/// One `[[version]]` table.
String _version({
  required String version,
  required int abi,
  String? path,
  String? url,
  String? sha256,
  String? notes,
}) => [
  '',
  '[[version]]',
  'version = "$version"',
  'abi = $abi',
  if (path != null) 'path = "$path"',
  if (url != null) 'url = "$url"',
  if (sha256 != null) 'sha256 = "$sha256"',
  'size = 100',
  if (notes != null) 'notes = "$notes"',
].join('\n');

/// One plugin's file.
String _pluginFile({
  String id = 'app.serverbox.test',
  String name = 'Test',
  required List<String> versions,
}) => [
  'id = "$id"',
  'name = "$name"',
  'description = "A plugin."',
  ...versions,
].join('\n');

void main() {
  late Directory root;
  late _FakeRepo repo;
  late PluginInstaller installer;

  setUpAll(initRustLibForTest);

  setUp(() async {
    await openTestDb();
    // Installing reads the development directories and writes the arrangement,
    // both of which go through `Stores.setting`.
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    root = await Directory.systemTemp.createTemp('sbp-store-');
    repo = _FakeRepo();
    installer = PluginInstaller(root: root);
    PluginContributions.clear();
    PluginRepoStore.instance.put(
      PluginRepoRecord(url: _repoUrl, addedAt: DateTime(2026)),
    );
  });

  tearDown(() async {
    PluginContributions.clear();
    await getIt.reset();
    await closeTestDb();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A package, and where a repository would carry it.
  ({List<int> bytes, String path, String url, String digest}) package({
    String version = '1.0.0',
    int abi = 1,
    String id = 'app.serverbox.test',
    List<String> permissions = const ['server.exec'],
  }) {
    final bytes = buildSbp(
      manifest: pluginManifest(
        id: id,
        version: version,
        abi: abi,
        permissions: permissions,
      ),
    );
    return (
      bytes: bytes,
      path: 'packages/$id-$version.sbp',
      url: '$_elsewhere/$id-$version.sbp',
      digest: PluginDigest.of(bytes),
    );
  }

  /// Serves a repository offering exactly these plugin files, plus the packages
  /// they carry.
  void serveRepo(
    Map<String, String> plugins, {
    Map<String, List<int>> packages = const {},
  }) {
    repo.serveTree({
      'repo.toml': utf8.encode('schema = 1\nname = "Test tap"'),
      for (final e in plugins.entries) e.key: utf8.encode(e.value),
      for (final e in packages.entries) e.key: e.value,
    });
  }

  /// The common case: one plugin, one version, carried in the repository.
  void serveOne({
    String version = '1.0.0',
    int abi = 1,
    List<String> permissions = const ['server.exec'],
    bool withDigest = true,
    String? notes,
  }) {
    final pkg = package(version: version, abi: abi, permissions: permissions);
    serveRepo(
      {
        'plugins/app/serverbox/test.toml': _pluginFile(
          versions: [
            _version(
              version: version,
              abi: abi,
              path: pkg.path,
              sha256: withDigest ? pkg.digest : null,
              notes: notes,
            ),
          ],
        ),
      },
      packages: {pkg.path: pkg.bytes},
    );
  }

  /// Lets real work progress, then draws the result.
  ///
  /// `runAsync` for the work and a pump outside it for the frame: a download
  /// and an install are real async — a socket, a filesystem — and only the
  /// real event loop moves them, while only a pump produces a frame.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PluginStorePage(
          source: PluginRepoSource(dio: Dio()..httpClientAdapter = repo),
          installer: installer,
        ),
      ),
    );
    // The index is fetched from `initState`, so the first frame is a spinner
    // and the list only exists once it answers. Waited for rather than slept
    // through: the spinner going is the page saying it has an answer, where a
    // fixed delay is a bet on how loaded the machine is.
    for (var i = 0; i < 100; i++) {
      await settle(tester);
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
  }

  /// Taps a button by its label and lets what it started run to the end.
  ///
  /// **The tap is dispatched inside `runAsync`, and it has to be.** A tap from
  /// the fake-async zone starts a chain whose filesystem awaits are registered
  /// in that zone, and alternating `runAsync` and `pump` around it does not
  /// deliver them: the download completed, and the install then stopped at its
  /// first `Directory.exists()` and stayed there through 250 rounds. Dispatched
  /// here, the whole chain belongs to the real zone and every await completes.
  ///
  /// [until] is what the tap was supposed to achieve, and giving it is what
  /// makes the test wait for the machine it is on rather than for a number
  /// somebody guessed. A fixed sleep passed alone and failed inside the full
  /// suite, where the same install has to share the machine.
  Future<void> tap(
    WidgetTester tester,
    String label, {
    bool Function()? until,
  }) async {
    await tester.runAsync(() => tester.tap(find.text(label).last));
    // Without an [until] this is a budget rather than a wait: the tests that
    // assert *nothing* happened have no state to watch, and giving up early
    // would be the way they pass for the wrong reason.
    //
    // **With one, the ceiling only costs time when something is wrong** — the
    // loop breaks the moment the condition holds — so it is set for the worst
    // machine rather than for this one. An install is an HTTP mock, a tar
    // extraction, a manifest parsed through the FFI and a directory written,
    // and two seconds of that is comfortable alone and not comfortable with
    // the rest of the suite running beside it: this failed about one full run
    // in three and passed every time the file was run on its own.
    for (var i = 0; i < (until == null ? 10 : 500); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      if (until != null && until()) break;
    }
    // One more round after the condition holds. Every [until] here watches
    // *state* — a record written, a dialog mounted — and the page redraws after
    // that, so stopping the moment the condition is true leaves the screen a
    // step behind what the store says.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  /// What is installed, for a [tap]'s `until`.
  String? installedVersion([String id = 'app.serverbox.test']) =>
      PluginInstallStore.instance.fetch(id)?.version;

  bool Function() showing(String text) =>
      () => find.text(text).evaluate().isNotEmpty;

  group('installing', () {
    testWidgets('a verified package is installed and the list says so', (
      tester,
    ) async {
      serveOne();

      await open(tester);
      expect(find.text('Test'), findsOneWidget);

      await tap(tester, l10n.pluginInstall, until: showing(libL10n.ok));
      await tap(tester, libL10n.ok, until: () => installedVersion() != null);

      final record = PluginInstallStore.instance.fetch('app.serverbox.test');
      expect(record, isNotNull);
      expect(record!.version, '1.0.0');
      // Where it came from, so an update knows which repository to look in.
      expect(record.repo, _repoUrl);
      expect(record.granted, {'server.exec'});
      expect(find.text(l10n.pluginInstalled), findsOneWidget);
      // One request for the whole repository, and none for the package: the
      // tree carried it.
      expect(repo.requested, [_archiveUrl]);
    });

    /// A mismatch means one of the file and the package was changed after the
    /// other. There is no version of that worth proceeding through, so there is
    /// no dialog — and the check has to happen before anything is written.
    testWidgets('a package that is not the one described is refused', (
      tester,
    ) async {
      final pkg = package();
      serveRepo(
        {
          'plugins/app/serverbox/test.toml': _pluginFile(
            versions: [
              _version(
                version: '1.0.0',
                abi: 1,
                path: pkg.path,
                sha256: PluginDigest.of(utf8.encode('something else')),
              ),
            ],
          ),
        },
        packages: {pkg.path: pkg.bytes},
      );

      await open(tester);
      await tap(tester, l10n.pluginInstall);

      expect(PluginInstallStore.instance.readAll(), isEmpty);
      // No consent dialog: it would be asking whether to run code that is not
      // what anybody described.
      expect(find.text(libL10n.ok), findsNothing);
      expect(find.text(l10n.pluginInstall), findsOneWidget);
    });

    /// A file naming a package the tree does not carry. Nothing is installed and
    /// nothing is fetched — the path is not an address, so there is nowhere to
    /// go looking.
    testWidgets('a package the repository does not carry installs nothing', (
      tester,
    ) async {
      final pkg = package();
      serveRepo({
        'plugins/app/serverbox/test.toml': _pluginFile(
          versions: [
            _version(
              version: '1.0.0',
              abi: 1,
              path: pkg.path,
              sha256: pkg.digest,
            ),
          ],
        ),
      });

      await open(tester);
      await tap(tester, l10n.pluginInstall);

      expect(PluginInstallStore.instance.readAll(), isEmpty);
      expect(repo.requested, [_archiveUrl]);
    });

    group('a package with no checksum', () {
      testWidgets('is not installed until the warning is answered', (
        tester,
      ) async {
        serveOne(withDigest: false);

        await open(tester);
        await tap(
          tester,
          l10n.pluginInstall,
          until: showing(l10n.pluginNoChecksum),
        );

        // The warning is up and nothing has been installed. The bytes came with
        // the repository, so what is being asked is whether to *run* something
        // nobody can check — which is the question either way.
        expect(find.text(l10n.pluginNoChecksum), findsOneWidget);
        expect(PluginInstallStore.instance.readAll(), isEmpty);
      });

      testWidgets('cancelling leaves it alone', (tester) async {
        serveOne(withDigest: false);

        await open(tester);
        await tap(
          tester,
          l10n.pluginInstall,
          until: showing(l10n.pluginNoChecksum),
        );
        await tap(tester, libL10n.cancel);

        expect(PluginInstallStore.instance.readAll(), isEmpty);
      });

      testWidgets('going ahead installs it', (tester) async {
        serveOne(withDigest: false);

        await open(tester);
        await tap(
          tester,
          l10n.pluginInstall,
          until: showing(l10n.pluginNoChecksum),
        );
        // The warning, then the permissions — the second dialog is what says
        // the first was answered.
        await tap(tester, libL10n.ok, until: showing(l10n.pluginPermissionsAsk));
        await tap(tester, libL10n.ok, until: () => installedVersion() != null);

        expect(PluginInstallStore.instance.fetch('app.serverbox.test'), isNotNull);
      });

      /// A package served from outside the repository is the case where the
      /// ordering still shows: **asked before the download**, since afterwards
      /// the bytes are already on the device and the question is a worse one.
      testWidgets('one served from elsewhere is not even fetched', (
        tester,
      ) async {
        final pkg = package();
        serveRepo({
          'plugins/app/serverbox/test.toml': _pluginFile(
            versions: [_version(version: '1.0.0', abi: 1, url: pkg.url)],
          ),
        });
        repo.serve(pkg.url, pkg.bytes);

        await open(tester);
        await tap(
          tester,
          l10n.pluginInstall,
          until: showing(l10n.pluginNoChecksum),
        );

        expect(repo.requested, [_archiveUrl]);

        await tap(tester, libL10n.ok, until: showing(l10n.pluginPermissionsAsk));

        // Only now, and from the address the file named.
        expect(repo.requested, [_archiveUrl, pkg.url]);
      });
    });

    /// Listed rather than hidden, and with no button: hiding it reads as the
    /// plugin not existing, and a button would be one that fails after a
    /// download.
    testWidgets('a release this build is too old for cannot be installed', (
      tester,
    ) async {
      final abi = ffi.pluginAbiVersion();
      serveRepo({
        'plugins/app/serverbox/test.toml': _pluginFile(
          versions: [
            _version(
              version: '9.0.0',
              abi: abi + 1,
              path: 'packages/too-new.sbp',
              sha256: PluginDigest.of(const [1]),
            ),
          ],
        ),
      });

      await open(tester);

      expect(find.text('Test'), findsOneWidget);
      expect(find.text(l10n.pluginNeedsNewerApp), findsOneWidget);
      expect(find.text(l10n.pluginInstall), findsNothing);
    });
  });

  group('updating', () {
    /// Install [from], then serve a repository offering [to] as well.
    Future<void> outdated(
      WidgetTester tester, {
      String from = '1.0.0',
      String to = '1.1.0',
      List<String> permissions = const ['server.exec'],
      String? notes,
    }) async {
      final old = package(version: from);
      await tester.runAsync(
        () => installer.install(
          old.bytes,
          consented: {'server.exec'},
          repo: _repoUrl,
        ),
      );

      final next = package(version: to, permissions: permissions);
      serveRepo(
        {
          'plugins/app/serverbox/test.toml': _pluginFile(
            versions: [
              _version(
                version: from,
                abi: 1,
                path: old.path,
                sha256: old.digest,
              ),
              _version(
                version: to,
                abi: 1,
                path: next.path,
                sha256: next.digest,
                notes: notes,
              ),
            ],
          ),
        },
        packages: {old.path: old.bytes, next.path: next.bytes},
      );
      await open(tester);
    }

    testWidgets('an update runs the same path and keeps the record', (
      tester,
    ) async {
      await outdated(tester);

      expect(find.text(l10n.pluginUpdatesAvailable(1)), findsOneWidget);
      await tap(tester, libL10n.update, until: () => installedVersion() == '1.1.0');

      final record = PluginInstallStore.instance.fetch('app.serverbox.test');
      expect(record!.version, '1.1.0');
      expect(record.granted, {'server.exec'});
    });

    /// The rule `askPluginUpgradeConsent` holds, from the outside: the dialog
    /// is what makes an added permission visible, so an update that adds none
    /// does not put one up. `plugin_consent_test.dart` covers the other half.
    testWidgets('asks nothing when the permissions have not moved', (
      tester,
    ) async {
      await outdated(tester);
      await tap(tester, libL10n.update, until: () => installedVersion() == '1.1.0');

      expect(find.text(libL10n.ok), findsNothing);
      expect(
        PluginInstallStore.instance.fetch('app.serverbox.test')!.version,
        '1.1.0',
      );
    });

    testWidgets('asks when the new version wants more', (tester) async {
      await outdated(tester, permissions: ['server.exec', 'server.list']);
      await tap(tester, libL10n.update, until: showing(libL10n.ok));

      expect(find.text(libL10n.ok), findsOneWidget);
      await tap(tester, libL10n.ok, until: () => installedVersion() == '1.1.0');

      final record = PluginInstallStore.instance.fetch('app.serverbox.test')!;
      expect(record.version, '1.1.0');
      expect(record.granted, {'server.exec', 'server.list'});
    });

    testWidgets('refusing the new permission leaves the old version', (
      tester,
    ) async {
      await outdated(tester, permissions: ['server.exec', 'server.list']);
      await tap(tester, libL10n.update, until: showing(libL10n.ok));
      await tap(tester, libL10n.cancel);

      final record = PluginInstallStore.instance.fetch('app.serverbox.test')!;
      expect(record.version, '1.0.0');
      expect(record.granted, {'server.exec'});
    });

    /// Shown on the tile rather than in a dialog: it is what somebody about to
    /// press Update is asking, and a dialog for it would be one more thing to
    /// tap through.
    testWidgets('what the repository says changed is on screen', (tester) async {
      await outdated(tester, notes: 'Faster on big directories.');

      expect(find.textContaining('Faster on big directories.'), findsOneWidget);
    });

    /// The progress is countable because the number of plugins is known before
    /// the first one starts — and it is counted in plugins rather than bytes:
    /// a package is tens of kilobytes, so a byte bar would run to the end and
    /// then sit through the part that actually takes the time.
    ///
    /// Caught mid-run by giving the second plugin a permission the first did
    /// not have: the consent dialog holds the run open, which is exactly the
    /// moment the bar has stopped and has to say why.
    testWidgets('an update all says where it is, and what it is waiting for', (
      tester,
    ) async {
      final ids = ['app.serverbox.one', 'app.serverbox.two'];
      final plugins = <String, String>{};
      final packages = <String, List<int>>{};
      for (final id in ids) {
        final old = package(id: id, version: '1.0.0');
        final next = package(
          id: id,
          version: '2.0.0',
          // The second asks for more, so its update stops for an answer.
          permissions: id == ids.last
              ? const ['server.exec', 'server.list']
              : const ['server.exec'],
        );
        await tester.runAsync(
          () => installer.install(
            old.bytes,
            consented: {'server.exec'},
            repo: _repoUrl,
          ),
        );
        plugins[PluginRepoLayout.pathOf(id)!] = _pluginFile(
          id: id,
          name: id,
          versions: [
            _version(
              version: '2.0.0',
              abi: 1,
              path: next.path,
              sha256: next.digest,
            ),
          ],
        );
        packages[next.path] = next.bytes;
      }
      serveRepo(plugins, packages: packages);
      await open(tester);

      await tap(tester, l10n.pluginUpdateAll, until: showing(libL10n.ok));

      // One is done, the second is on screen and the run is held open by its
      // dialog — so the bar says which plugin, and that it is waiting.
      expect(installedVersion(ids.first), '2.0.0');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(l10n.pluginWaitingForYou(ids.last)), findsOneWidget);
      // And the row it is at says so too, in place of its button.
      expect(find.text(l10n.pluginUpdating), findsOneWidget);
      expect(find.text(l10n.pluginStopAfterThis), findsOneWidget);

      await tap(
        tester,
        libL10n.ok,
        until: () => installedVersion(ids.last) == '2.0.0',
      );

      // And when it is over there is no bar left behind.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(l10n.pluginUpdating), findsNothing);
    });

    testWidgets('update all takes every one of them', (tester) async {
      // Two plugins, both a version behind, in one repository.
      final ids = ['app.serverbox.one', 'app.serverbox.two'];
      final plugins = <String, String>{};
      final packages = <String, List<int>>{};
      for (final id in ids) {
        final old = package(id: id, version: '1.0.0');
        final next = package(id: id, version: '2.0.0');
        await tester.runAsync(
          () => installer.install(
            old.bytes,
            consented: {'server.exec'},
            repo: _repoUrl,
          ),
        );
        plugins[PluginRepoLayout.pathOf(id)!] = _pluginFile(
          id: id,
          name: id,
          versions: [
            _version(
              version: '2.0.0',
              abi: 1,
              path: next.path,
              sha256: next.digest,
            ),
          ],
        );
        packages[next.path] = next.bytes;
      }
      serveRepo(plugins, packages: packages);

      await open(tester);
      expect(find.text(l10n.pluginUpdatesAvailable(2)), findsOneWidget);

      await tap(
        tester,
        l10n.pluginUpdateAll,
        until: () => ids.every((id) => installedVersion(id) == '2.0.0'),
      );

      for (final id in ids) {
        expect(
          PluginInstallStore.instance.fetch(id)!.version,
          '2.0.0',
          reason: id,
        );
      }
    });
  });

  /// The id is the same and the bytes are somebody else's. It happened for
  /// real: a working tree registered as a development directory sat at a
  /// version the repository had never published, the row offered an update, and
  /// taking it wrote a record naming a version from GitHub over a plugin the
  /// app went on loading from the tree.
  group('a copy this repository did not install', () {
    /// Installs 1.0.0 from [from], then serves a repository offering 1.1.0.
    Future<void> installedElsewhere(WidgetTester tester, String from) async {
      final have = package();
      await tester.runAsync(
        () => installer.install(
          have.bytes,
          consented: {'server.exec'},
          repo: from,
        ),
      );
      serveOne(version: '1.1.0');
      await open(tester);
    }

    testWidgets('is not an update, and the row says whose it is', (
      tester,
    ) async {
      await installedElsewhere(tester, PluginInstall.devRepo);

      expect(find.text(l10n.pluginUpdatesAvailable(1)), findsNothing);
      expect(find.text(l10n.pluginUpdateAll), findsNothing);
      expect(find.text(libL10n.update), findsNothing);
      expect(find.text(l10n.pluginReplace), findsOneWidget);
      expect(
        find.textContaining(l10n.pluginInstalledFrom('v1.0.0 · ${l10n.pluginDev}')),
        findsOneWidget,
      );
    });

    testWidgets('replacing it is asked about first', (tester) async {
      await installedElsewhere(tester, PluginInstall.fileRepo);
      await tap(tester, l10n.pluginReplace, until: showing(l10n.pluginReplace));

      // The dialog is up and nothing has been touched: the copy on the device
      // is still the one that was there.
      expect(find.text(l10n.pluginReplace), findsNWidgets(2));
      expect(installedVersion(), '1.0.0');

      await tap(tester, libL10n.cancel);
      final kept = PluginInstallStore.instance.fetch('app.serverbox.test')!;
      expect(kept.version, '1.0.0');
      expect(kept.origin, PluginOrigin.file);
    });

    testWidgets('and going ahead moves it to this repository', (tester) async {
      await installedElsewhere(tester, PluginInstall.fileRepo);
      await tap(tester, l10n.pluginReplace, until: showing(l10n.pluginReplace));
      await tap(tester, libL10n.ok, until: () => installedVersion() == '1.1.0');

      final record = PluginInstallStore.instance.fetch('app.serverbox.test')!;
      expect(record.version, '1.1.0');
      // Which is what makes the *next* one an ordinary update.
      expect(record.repo, _repoUrl);
      expect(record.granted, {'server.exec'});
    });
  });

  group('repositories', () {
    testWidgets('none is an empty state that offers to add one', (tester) async {
      PluginRepoStore.instance.remove(_repoUrl);

      await open(tester);

      expect(find.text(l10n.pluginNoRepos), findsOneWidget);
      expect(find.text(l10n.pluginAddRepo), findsOneWidget);
    });

    /// The one place a repository's own name is ever learned. Read on every
    /// fetch and, before this, thrown away — so every GitHub-hosted repository
    /// was listed by its address, and they all start with the same host.
    testWidgets('what it calls itself is kept', (tester) async {
      serveOne();

      await open(tester);

      final record = PluginRepoStore.instance.fetch(_repoUrl)!;
      expect(record.name, 'Test tap');
      expect(record.label, 'Test tap');
    });

    /// The page says which repository is broken. A short list with no reason is
    /// indistinguishable from a repository that offers nothing.
    testWidgets('one that cannot be read says so', (tester) async {
      await open(tester);

      expect(find.text(l10n.pluginStoreEmpty), findsOneWidget);
      expect(find.textContaining('404'), findsOneWidget);
    });

    testWidgets('a disabled one contributes nothing', (tester) async {
      serveOne();
      PluginRepoStore.instance.setEnabled(_repoUrl, false);

      await open(tester);

      expect(find.text('Test'), findsNothing);
      expect(repo.requested, isEmpty);
    });
  });
}
