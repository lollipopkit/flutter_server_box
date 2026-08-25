import 'dart:async';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/app.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/core/utils/rootfs_manifest_source.dart';
import 'package:server_box/core/utils/sandbox_import.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/dist_license.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/session_manager.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/hive/hive_registrar.g.dart';
import 'package:server_box/hive/legacy_adapters.dart';
import 'package:server_box/src/rust/frb_generated.dart';

Future<void> main() async {
  await _runInZone(() async {
    await _initApp();
    runApp(ProviderScope(child: const MyApp()));
    _greetDev();
  });
}

/// Raises a pile of toasts a second after launch, on debug builds only.
///
/// After [runApp] rather than in [_setupDebug]: the `ToastHost` only exists
/// once the first frame has built, and the initialization still to come after
/// `_setupDebug` can outlast the delay — the toasts would then be raised with
/// no host to draw them.
void _greetDev() {
  if (!kDebugMode) return;
  Future.delayed(const Duration(seconds: 1), _showDevToasts);
}

/// One of each shape, staggered so that they visibly pile up.
///
/// Covers what is worth looking at: every level, a title too long for its line,
/// a body worth opening, an action button, and — with five of them — the two
/// edges that show behind the front one plus the level past that which does not.
///
/// They stay long enough to be opened and read, rather than until dismissed:
/// clearing five toasts by hand on every hot restart is its own annoyance.
Future<void> _showDevToasts() async {
  const gap = Duration(milliseconds: 300);
  const stay = Duration(seconds: 12);

  Toast.show('welcome, dev!', duration: stay);
  await Future.delayed(gap);

  Toast.success('Saved', body: 'to /etc/nginx/nginx.conf', duration: stay);
  await Future.delayed(gap);

  Toast.warn('Disk almost full', body: '/dev/sda1 at 94%', duration: stay);
  await Future.delayed(gap);

  Toast.error(
    'SSHError: connection to 192.168.1.100 was refused after three attempts',
    body:
        'SocketException: Connection refused (OS Error: Connection refused, '
        'errno = 61), address = 192.168.1.100, port = 22',
    duration: stay,
  );
  await Future.delayed(gap);

  Toast.info(
    'New version available',
    duration: stay,
    action: ToastAction(label: 'Update', onTap: () {}),
  );
}

Future<void> _runInZone(Future<void> Function() body) async {
  final zoneSpec = ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      parent.print(zone, line);
    },
  );

  await runZonedGuarded(
    body,
    (e, s) => Loggers.app.warning('Zone error', e, s),
    zoneSpecification: zoneSpec,
  );
}

Future<void> _initApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Shared parsing library (sbm_parser FFI, see the shared-parser design)
  await RustLib.init();
  // Before anything can open the licence page. Cheap: the callback only runs
  // when that page asks for it.
  registerDistMarkLicenses();
  await _initData();
  _setupDebug();
  await _initWindow();

  await _doPlatformRelated();

  // Initialize platform session notifications and Live Activities.
  await TermSessionManager.init();
}

Future<void> _initData() async {
  // Versioned on purpose. Sync is a single shared file on iCloud/WebDAV/Gist,
  // and `SyncIface._sync` uploads unconditionally after a failed merge — so a
  // build that cannot read the remote copy overwrites it. Builds already
  // released have no version check and cannot be given one, and the only thing
  // that stops them is not seeing the file at all.
  //
  // TODO: drop the legacy name (and `BakSyncer.inheritLegacyRemote`) once no
  // install can still be writing `srvbox_bak.json`.
  // `img` holds the SSH background, `font` the terminal font. The rest of
  // `PathDir` belongs to other apps on fl_lib, and creating them here would
  // only leave empty directories beside the boxes.
  await Paths.init(
    BuildData.name,
    bakName: Miscs.bakFileName,
    dirs: const {PathDir.img, PathDir.font},
  );

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

  // Where the Linux userland is, and whether there is one — proot and an
  // unpacked rootfs on Android, the engine and its filesystem on iOS. A few
  // file checks, and the terminal tab reads the answer while building.
  try {
    await Rootfs.prepare();
  } catch (e, s) {
    Loggers.app.warning('Failed to locate the Linux rootfs', e, s);
  }

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
    unawaited(RootfsManifestSource.refresh());
  }

  // The watch app used to learn about servers only while the user sat on the
  // iOS settings page. Pushing at launch is what makes a freshly installed or
  // restored watch configure itself.
  if (isIOS) {
    unawaited(WatchSync.instance.init());
    unawaited(MethodChans.syncAccessoryWidgetUrl());
  }

  // Both platforms keep their own copy of this, which a reinstall or a restored
  // backup leaves disagreeing with the settings store.
  if (isIOS || isAndroid) {
    unawaited(MethodChans.setPrivacyBlur(Stores.setting.privacyBlur.fetch()));
  }

  final serversCount = Stores.server.keys().length;
  await Computer.shared.turnOn(
    workersCount: (serversCount / 3).round() + 1,
  ); // Plus 1 to avoid 0.
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

  final lastVer = Stores.setting.lastVer.fetch();
  const newVer = BuildData.build;
  // It's only the version upgrade trigger logic.
  // How to upgrade the data is inside each own func.
  if (lastVer < newVer) {
    ServerDetailCards.autoAddNewCards(newVer);
    ServerFuncBtn.autoAddNewFuncs(lastVer, newVer);
    Stores.setting.lastVer.put(newVer);
  }

  // No app-level fixups follow. `migrateIds` and `migrateIdentityFilePaths`
  // both scanned every server on every launch to repair a record only an
  // upgrading install can hold; both are part of `KvToTablesMigration` now,
  // which is the one pass that sees that shape. Neither could have run after
  // it in any case — an empty `Spi.id` has nowhere to live once the id is a
  // primary key, and mapping the old private key ids would have turned an
  // `IdentityFile` path into a null before anything could recognise it.

  // Pick up sync history written under the pre-v3 remote filename. Runs at
  // most once per remote and is best-effort — see `inheritLegacyRemote`.
  unawaited(bakSync.inheritLegacyRemote());
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
