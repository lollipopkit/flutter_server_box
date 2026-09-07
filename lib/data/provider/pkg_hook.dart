import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';

/// What a surface is asking to be collected, and for which machines.
///
/// The pending-package reading is not on a timer — see
/// [ServerNotifier.refreshPkg] — so something has to ask, and what is asked
/// for depends on what is being looked at. The updates tab lists every machine
/// and needs every count; a server's own page shows one card and needs one.
/// Both go through here so the two cannot drift into asking differently.
///
/// **The scope is the caller's and the collection is not.** A surface says
/// which machines it is about; how a reading is taken, how often it may be
/// retaken and what happens when a machine cannot answer belong to the
/// notifier. That split is what a plugin's version of this has to keep: the
/// host fires the hook with the scope, and what to load out of it is the
/// plugin's decision.
enum PkgHookScope {
  /// Every server the app knows. Raised by the updates tab, whose whole
  /// content is a count per machine.
  fleet,

  /// One server. Raised by its detail card and by its own updates page.
  server,
}

/// Fires the collection a surface is asking for.
///
/// Idempotent and cheap to call on every build of the thing that opens: a
/// collection already in flight for a server is not started twice
/// ([ServerNotifier.refreshPkg] holds that), and a server with no connection
/// is skipped rather than queued.
class PkgHook {
  const PkgHook._();

  /// [serverId] is required for [PkgHookScope.server] and ignored otherwise.
  ///
  /// Not awaited by its callers: a page draws what it has and fills in as the
  /// answers land, which is the whole point of collecting on the way in rather
  /// than on a timer. Failures are the notifier's to log — a page that could
  /// not read one machine's packages is not a page that failed.
  /// A `WidgetRef`, because every caller is a widget being entered. A
  /// provider-side `Ref` shares no supertype with it and nothing needs one;
  /// an overload can be added when something does.
  static void fire(
    WidgetRef ref,
    PkgHookScope scope, {
    String? serverId,
  }) {
    switch (scope) {
      case PkgHookScope.server:
        assert(serverId != null, 'a server scope names a server');
        if (serverId == null) return;
        _one(ref, serverId);
      case PkgHookScope.fleet:
        // In the order the server tab shows them, so the first answers to
        // arrive are for the rows at the top of the list — which is where the
        // eye is while the rest come in.
        for (final id in ref.read(serversProvider).serverOrder) {
          _one(ref, id);
        }
    }
  }

  static void _one(WidgetRef ref, String id) {
    // Unawaited on purpose; see [fire].
    ref.read(serverProvider(id).notifier).refreshPkg().ignore();
  }
}

/// [PkgHook.fire] from a widget, once per mount.
///
/// A mixin rather than a call in `initState`, because the call has to happen
/// after the first frame: `ref.read` on a provider that is being created
/// during a build is what throws, and a tab's first build is exactly when a
/// server notifier is created.
mixin PkgHookOnEnter<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  PkgHookScope get pkgHookScope;

  /// Null for [PkgHookScope.fleet].
  String? get pkgHookServerId => null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PkgHook.fire(ref, pkgHookScope, serverId: pkgHookServerId);
    });
  }
}
