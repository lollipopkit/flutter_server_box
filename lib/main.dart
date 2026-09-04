import 'dart:async';

import 'package:computer/computer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/app.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/service/crash_report.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/core/service/native_exit.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/core/service/widget_sync.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/core/utils/rootfs_manifest_source.dart';
import 'package:server_box/core/utils/sandbox_import.dart';
import 'package:server_box/core/utils/ssh_native_crypto.dart';
import 'package:server_box/data/model/server/dist_license.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/session_manager.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/build_features.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/tables.dart';
import 'package:server_box/hive/hive_registrar.g.dart';
import 'package:server_box/hive/legacy_adapters.dart';
import 'package:server_box/src/rust/frb_generated.dart';

Future<void> main() async {
  await _runInZone(() async {
    await _initApp();
    runApp(ProviderScope(child: const MyApp()));
  });
}

Future<void> _runInZone(Future<void> Function() body) async {
  final zoneSpec = ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      parent.print(zone, line);
    },
  );

  await runZonedGuarded(
    body,
    (e, s) {
      // `CrashLog.handleErrors` also installs `PlatformDispatcher.onError`,
      // and inside a guarded zone that handler is never reached: the zone
      // takes async errors first, and the two are alternatives rather than
      // layers. So this is the only place an uncaught async error is seen,
      // and marking has to happen here or not at all.
      //
      // Reporting has to happen here for the same reason, and it is the same
      // reason again that it cannot be left to `CrashLog`: that class only
      // sees what its own handlers catch, and this is precisely what they do
      // not. Most uncaught errors in this app are async, so without this the
      // sink hears about almost none of them.
      //
      // `LocalDiagnosticsSink.error` logs it, so logging it here as well would
      // record it twice — and with no sink installed nothing would be recorded
      // at all, which is what the fallback covers.
      if (Diag.enabled) {
        Diag.error(e, s, 'Zone error');
      } else {
        Loggers.app.severe('Zone error', e, s);
      }
      // Recorded either way above; only what the next launch does about it is
      // gated. A server that answers with something this app cannot parse is
      // not the app ending badly — see [CrashReport.isAppFault].
      //
      // The error travels into the marker so the next launch can report it if
      // nothing here did. Whether it is kept is decided by `CrashLog`, against
      // whether a sink was uploading at this moment — see [CrashLog.uploadsNow].
      if (CrashReport.isAppFault(e)) CrashLog.markUnhandled(e, s);
    },
    zoneSpecification: zoneSpec,
  );
}

Future<void> _initApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Before anything that can fail, so that a failure during startup is at
  // least recorded — the errors worth catching most are the ones that stop the
  // app from reaching a screen anyone could copy a log from.
  //
  // Bounded by what it can do without a path: lines are buffered in memory
  // and written once `CrashLog.attach` below has one, and the marker that
  // tells the next launch this run died is a file, so neither exists until
  // then. That window is now two platform channels wide rather than the whole
  // of `_initData`. What covers even that is the platform's own record of the
  // exit, read on the following launch — see [NativeExitReport].
  _setupDebug();

  // Before `RustLib.init`, and that ordering is the point. `_setupDebug`
  // buffers into memory and can do nothing else until there is a path; the
  // marker that tells the next launch this one died is a *file*, so until this
  // runs a crash leaves no marker and the buffered lines are never written.
  // This used to sit at the top of `_initData`, which runs after the Rust
  // library, the database and the schema migration — the three things most
  // likely to take the process down, and precisely the ones whose failure went
  // unrecorded. Nothing here needs Rust: both are platform channels.
  //
  // `img` holds the SSH background, `font` the terminal font. The rest of
  // `PathDir` belongs to other apps on fl_lib, and creating them here would
  // only leave empty directories beside the boxes.
  //
  // `bakName` is versioned on purpose. Sync is a single shared file on
  // iCloud/WebDAV/Gist, and `SyncIface._sync` uploads unconditionally after a
  // failed merge — so a build that cannot read the remote copy overwrites it.
  // Builds already released have no version check and cannot be given one, and
  // the only thing that stops them is not seeing the file at all.
  //
  // TODO: drop the legacy name (and `BakSyncer.inheritLegacyRemote`) once no
  // install can still be writing `srvbox_bak.json`.
  await Paths.init(
    BuildData.name,
    bakName: Miscs.bakFileName,
    dirs: const {PathDir.img, PathDir.font},
  );
  await CrashLog.attach(Paths.doc.joinPath('logs'));
  // Which release a report came from is the first thing asked about one and
  // the thing users most often leave out.
  Diag.tag(SbDiagTag.build, '${BuildData.build}');
  Diag.crumb(DiagCategory.lifecycle, 'launch');

  // Shared parsing library (sbm_parser FFI, see the shared-parser design)
  await RustLib.init();
  // Every SSH connection this isolate opens computes AES and HMAC through the
  // same library from here on, instead of in Dart on the isolate drawing
  // frames. Read when a connection installs its keys, so it has to be in place
  // before the first one — see [NativeSshCrypto].
  sshCryptoBackend = const NativeSshCrypto();
  // Before anything can open the licence page. Cheap: the callback only runs
  // when that page asks for it.
  registerDistMarkLicenses();
  await _initData();
  await _initWindow();

  await _doPlatformRelated();

  // Initialize platform session notifications and Live Activities.
  await TermSessionManager.init();
}

Future<void> _initData() async {
  // `extended_image` caches under `getTemporaryDirectory()` and makes its own
  // folder there with a plain `create()`, no `recursive`. On macOS that
  // directory is `~/Library/Caches/<bundle id>`, which nothing has to have
  // made yet — a fresh install, or a machine whose caches were swept. Every
  // image then failed with `PathNotFoundException` and no fallback, which is
  // what a server logo turning into an error in the log was.
  //
  // TODO: drop once extended_image_library creates its folder recursively.
  await (await getTemporaryDirectory()).create(recursive: true);

  // Only so `HiveImport` can read the boxes an upgrading install still has.
  // Nothing writes Hive any more.
  //
  // TODO: drop this, `lib/hive/` and the `hive_ce*` dependencies together with
  // `HiveImport`, once no supported install can still be on Hive.
  await Hive.initFlutter();
  Hive.registerAdapters();
  // Reads every released server-record layout. The generated adapters no
  // longer own the frozen type IDs because nothing writes Hive any more.
  registerHiveLegacyAdapters();

  await PrefStore.shared.init(); // Call this before accessing any store
  await SecureStoreProps.migrateLegacyPrefs();
  await Future.wait([Webdav.initShared(), GistRs.initShared()]);

  // Before a box is opened, because it rewrites the files they are made of.
  // After the preferences, because the data it copies may be encrypted with a
  // key that old installs keep there. See [SandboxImport].
  final imported = await SandboxImport.run();

  try {
    await Stores.init();
  } catch (e, s) {
    if (imported != SandboxImportResult.imported) rethrow;

    // The copied data does not open. It was only ever a copy, so drop it and
    // start empty — an app that opens with nothing in it can still be told
    // what happened, one that does not open cannot.
    Loggers.app.warning('Stores.init after sandbox import', e, s);
    // Closed before the files are deleted. `Stores.init` may have got as far as
    // opening the database, or several boxes, before the one that threw, and
    // unlinking a file out from under a live handle is undefined at best: on
    // Windows the delete fails outright and the copy stays, so the retry below
    // reopens exactly the data that just failed to open.
    await closeTables();
    await SqliteDb.close();
    await Hive.close();
    await getIt.reset();
    await SandboxImport.undo();
    await Stores.init();
  }

  // It may effect the following logic, so await it.
  // DO DB migration before load any provider.
  await _doDbMigrate();

  if (Stores.setting.betaTest.fetch()) AppUpdate.chan = AppUpdateChan.beta;

  FontUtils.loadFrom(Stores.setting.fontPath.fetch());
}

void _setupDebug() {
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    DebugProvider.addLog(record);
  });
  CrashLog.handleErrors();
  // Before the first error can arrive, so the marker knows from the outset
  // whether anything else is hearing about a crash. Answers false for most of
  // startup — the sink goes in at the end of `_doPlatformRelated` — which is
  // exactly the window whose crashes nothing used to report.
  CrashLog.uploadsNow = () => DiagnosticsUpload.uploading;
  // Local only, and that is the whole of it: nothing is sent anywhere, so
  // there is nothing to ask the user's permission for. The file is theirs
  // until they paste it into a report — which is also why a crumb has to be
  // publishable when it is written. See [Redact].
  Diag.install(LocalDiagnosticsSink());

  // Where the user was is the cheapest context there is, and the one every
  // report leaves out — two of the three open ones describe a route ("terminal,
  // then Device") in prose because there was nowhere for it to be recorded.
  //
  // A route name is a path, not data: arguments travel in `args`, so this
  // publishes `/server/detail` rather than which server.
  AppRouteObserver.addListener((settings, type) {
    Diag.crumb(
      DiagCategory.nav,
      type.name,
      data: {'route': settings?.name ?? '-'},
    );
  });

  // A no-op for the local sink, which writes synchronously — and installed
  // anyway, because that is exactly the kind of thing that is forgotten until
  // a sink that *does* buffer is added and quietly loses its last batch. Not
  // `home.dart`'s lifecycle callback: that one returns early on desktop and
  // only runs while the home page is mounted.
  //
  // Not held in a variable: the constructor registers it with the binding,
  // which keeps it alive for as long as the process is, and it is never
  // disposed.
  AppLifecycleListener(
    onPause: () => unawaited(Diag.flush()),
    onDetach: () => unawaited(Diag.flush()),
  );
}

Future<void> _doPlatformRelated() async {
  if (isAndroid) {
    // try switch to highest refresh rate
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e, s) {
      Loggers.app.warning('Failed to set high refresh rate', e, s);
    }
  }

  // Why the process died last time, which for a native crash is the only
  // record there is — nothing in Dart ran to write one. After the stores are
  // open, since it remembers which record it has already reported, and after
  // `CrashLog.attach`, whose answer about the previous run it may correct.
  await NativeExitReport.collect();

  // Adds the upload sink beside the local one, if this build has a DSN and the
  // user asked for it. Neither is true by default. Not awaited: the local sink
  // is already recording, and a slow or unreachable server must not hold up
  // startup to add a second destination for it.
  //
  // The crash report is split around it, because only half of it needs a sink.
  // Both orderings matter. `CrashReport.keep` writes the file the settings page
  // offers and waits for nothing — behind the sink it waited on `Sentry.init`
  // and two analytics clients, so on a slow endpoint the row was missing from a
  // page opened straight after launch. `CrashReport.report` files the error and
  // has nowhere to send it until the sink is in. Both are after
  // `NativeExitReport.collect` above, which is what may decide the previous run
  // ended badly at all.
  unawaited(() async {
    await CrashReport.keep();
    // Isolated, because a throw here would take `report` with it and leave the
    // previous run's crash unreported for the sake of an unrelated failure —
    // and, being unawaited, would reach the zone handler and mark *this* run
    // as having ended badly too.
    try {
      await DiagnosticsUpload.sync();
    } catch (e, s) {
      Loggers.app.warning('Crash upload sync failed', e, s);
    }
    CrashReport.report();
  }());

  // Where the Linux userland is, and whether there is one — proot and an
  // unpacked rootfs on Android, the engine and its filesystem on iOS. A few
  // file checks, and the terminal tab reads the answer while building.
  try {
    await Rootfs.prepare();
  } catch (e, s) {
    Loggers.app.warning('Failed to locate the Linux rootfs', e, s);
  }
  // Both open crash reports naming a terminal are on Android, and neither says
  // whether a Linux userland was involved at all.
  Diag.tag(SbDiagTag.rootfs, Rootfs.isAvailable ? 'yes' : 'no');

  // Which releases are installable is data that moves on the distributions'
  // schedule, so it is fetched rather than compiled in. Not awaited: what
  // `prepare` just adopted already works, and this only ever replaces it with
  // something newer that verified.
  //
  // Gated on the build carrying an engine at all. Most do not — iOS ships with
  // the switch off and Android needs a proot this repository does not contain —
  // and a request per launch for a feature that cannot be used is one nobody
  // asked for.
  if (Rootfs.isAvailable) {
    unawaited(
      (() async {
        try {
          await RootfsManifestSource.refresh();
        } catch (e, s) {
          Loggers.app.warning('Rootfs manifest refresh failed', e, s);
        }
      })(),
    );
  }

  // The watch app used to learn about servers only while the user sat on the
  // iOS settings page. Pushing at launch is what makes a freshly installed or
  // restored watch configure itself.
  if (isIOS) {
    unawaited(
      (() async {
        try {
          await WatchSync.instance.init();
        } catch (e, s) {
          Loggers.app.warning('WatchSync init failed', e, s);
        }
      })(),
    );
  }

  // Same reasoning, for the home-screen widgets: the list they offer on their
  // configuration screen is whatever this last published, and the container
  // holding it goes away with the app — so a reinstall has to re-publish
  // before a widget can be configured at all.
  if (isIOS || isAndroid) {
    unawaited(
      (() async {
        try {
          await WidgetSync.instance.init();
        } catch (e, s) {
          Loggers.app.warning('WidgetSync init failed', e, s);
        }
      })(),
    );
  }

  // Both platforms keep their own copy of this, which a reinstall or a restored
  // backup leaves disagreeing with the settings store.
  if (isIOS || isAndroid) {
    unawaited(
      (() async {
        try {
          await MethodChans.setPrivacyBlur(
            Stores.setting.privacyBlur.fetch(),
          );
        } catch (e, s) {
          Loggers.app.warning('setPrivacyBlur failed', e, s);
        }
      })(),
    );
  }

  // Status parsing used to run on this pool, which is why its size followed
  // the server count. It now runs on the Rust thread pool, while the remaining
  // Computer tasks (backup parsing, editor work and PVE responses) are
  // occasional and already queue safely. Starting several otherwise idle
  // isolates before the first frame only makes a larger server list slower and
  // more memory-hungry to open.
  await Computer.shared.turnOn(workersCount: 1);
}

// It may contains some async heavy funcs.
Future<void> _doDbMigrate() async {
  // Storage layout first: it must finish before anything decodes a record as
  // its current type. Throws SchemaTooNewException when the data was written
  // by a newer build — that must not be swallowed, since continuing would let
  // this build overwrite records whose shape it doesn't understand.
  //
  // First in this function, and not after the feature bump below, because that
  // refusal is only worth anything if nothing has been written yet. Run second,
  // it left `autoAddNewCards`, `autoAddNewFuncs` and a rewritten `lastVer`
  // behind on a database it then declined to touch — so a downgrade destroyed
  // exactly the settings the refusal exists to protect.
  await SchemaVersion.migrate(kSchemaMigrations);
  Diag.tag(SbDiagTag.schema, '${SchemaVersion.current}');

  migrateBuildFeatures(BuildData.build);

  // No app-level fixups follow. `migrateIds` and `migrateIdentityFilePaths`
  // both scanned every server on every launch to repair a record only an
  // upgrading install can hold; both are part of `KvToTablesMigration` now,
  // which is the one pass that sees that shape. Neither could have run after
  // it in any case — an empty `Spi.id` has nowhere to live once the id is a
  // primary key, and mapping the old private key ids would have turned an
  // `IdentityFile` path into a null before anything could recognise it.

  // Pick up sync history written under the pre-v3 remote filename. Runs at
  // most once per remote and is best-effort — see `inheritLegacyRemote`.
  unawaited(
    (() async {
      try {
        await bakSync.inheritLegacyRemote();
      } catch (e, s) {
        Loggers.app.warning('inheritLegacyRemote failed', e, s);
      }
    })(),
  );
}

Future<void> _initWindow() async {
  if (!isDesktop) return;
  final windowStateProp = Stores.setting.windowState;
  final windowState = windowStateProp.fetch();
  final hideTitleBar = Stores.setting.hideTitleBar.fetch();
  WindowFrameConfig.setShowCaption(hideTitleBar);
  await SystemUIs.initDesktopWindow(
    hideTitleBar: hideTitleBar,
    size: windowState?.size ?? Size(1323, 817),
    position: windowState?.position,
    listener: WindowStateListener(windowStateProp),
  );
}
