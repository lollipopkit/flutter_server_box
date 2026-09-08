import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/provider/plugin/app_ops.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;

part 'runtime.g.dart';

/// The app's one runtime, wired to the app's own way of doing things.
///
/// `keepAlive`, because it owns native threads and two request streams: a
/// runtime that came and went with a widget would leave an instance running
/// with nothing reading what it asks for.
@Riverpod(keepAlive: true)
PluginRuntimeService pluginRuntime(Ref ref) {
  final service = PluginRuntimeService(
    bridge: PluginBridge(
      ops: AppPluginHostOps(ref),
      handles: PluginServerHandles(),
    ),
  );
  // What a hook's `servers` are named by. The same answer
  // `AppPluginHostOps.listServers` gives, from the same store, so a plugin
  // reading a name out of a hook and one reading it out of `sb.server.list`
  // cannot see two different things.
  service.serverNameLookup = (id) =>
      ref.read(serversProvider).servers[id]?.name ?? '';
  ref.onDispose(service.dispose);
  return service;
}

/// The one plugin runtime, and the loop that answers what plugins ask for.
///
/// One per app rather than one per surface: the runtime already gives each
/// instance a thread of its own, and a second runtime would mean a second
/// request stream to keep reading.
///
/// **Whatever reads `requests` must keep reading.** A plugin blocks on its own
/// thread until its request is answered, so a dropped request is an instance
/// that stops until its host-call timeout — which is why the loop below
/// answers every one, including with a failure.
class PluginRuntimeService {
  PluginRuntimeService({required this.bridge});

  final PluginBridge bridge;

  ffi.PluginRuntime? _runtime;
  final _subs = <StreamSubscription<void>>[];

  /// Instance id by the number the runtime knows it as, so a request naming
  /// the number can be answered about the right instance.
  final _instanceIds = <BigInt, String>{};

  bool get started => _runtime != null;

  /// Starts the runtime and begins answering.
  ///
  /// Idempotent: the second caller gets the runtime the first one started.
  Future<void> start() async {
    if (_runtime != null) return;

    final requests = RustStreamSink<ffi.PluginRequest>();
    final logs = RustStreamSink<ffi.PluginLog>();
    // Listened to only after the sinks have been handed over: the stream does
    // not exist until the generated code has set it up.
    final runtime = await ffi.PluginRuntime.newInstance(
      requests: requests,
      logs: logs,
    );
    _runtime = runtime;

    _subs.add(requests.stream.listen((req) => unawaited(_answer(runtime, req))));
    _subs.add(logs.stream.listen(_log));
  }

  Future<void> _answer(ffi.PluginRuntime runtime, ffi.PluginRequest req) async {
    try {
      final answer = await bridge.answer(
        pluginId: req.pluginId,
        instanceId: req.instanceId,
        func: req.func,
        request: req.request,
      );
      runtime.answer(
        callId: req.callId,
        ok: answer.ok,
        errorKind: answer.errorKind,
        errorMessage: answer.errorMessage,
        denied: answer.denied,
      );
    } catch (e, s) {
      // The bridge answers rather than throws, so reaching here means the
      // answering itself failed. Answering with the failure is still the only
      // way the plugin gets to continue.
      Loggers.app.warning('Answering ${req.func} for ${req.pluginId}', e, s);
      try {
        runtime.answer(
          callId: req.callId,
          errorKind: 'internal',
          errorMessage: '$e',
        );
      } catch (_) {
        // The runtime is gone, which is what unloading does to the requests
        // still in flight. Nothing is waiting for this answer.
      }
    }
  }

  void _log(ffi.PluginLog log) {
    final message = '[${log.pluginId}] ${log.message}';
    switch (log.level) {
      case 'error':
        Loggers.app.warning(message);
      case 'warn':
        Loggers.app.warning(message);
      case 'info':
        Loggers.app.info(message);
      default:
        Loggers.app.fine(message);
    }
  }

  /// Loads a plugin against one surface.
  ///
  /// [instanceId] is unique per surface for as long as it is open, which is
  /// also the lifetime of the SDK's `frame()` state — one instance tracks one
  /// tree.
  Future<BigInt> load({
    required String manifestJson,
    required String source,
    required String instanceId,
    required List<String> granted,
    required Map<String, String> config,
    String? boundServerId,
  }) async {
    await start();
    final runtime = _runtime!;
    // Issued before the plugin can ask for anything: `init` may already call
    // `sb.server.exec`, and the handle has to resolve by then.
    final handle = boundServerId == null
        ? null
        : bridge.handles.bind(instanceId, boundServerId);
    final id = await runtime.load(
      spec: ffi.PluginSpec(
        manifestJson: manifestJson,
        source: source,
        instanceId: instanceId,
        granted: granted,
        config: [for (final e in config.entries) (e.key, e.value)],
        boundServer: handle,
      ),
    );
    _instanceIds[id] = instanceId;
    return id;
  }

  Future<String> call(BigInt instance, String export, String input) async {
    final runtime = _runtime;
    if (runtime == null) throw StateError('the plugin runtime is not started');
    return runtime.call(instance: instance, export_: export, input: input);
  }

  /// Tells a plugin a surface was entered.
  ///
  /// **The host says the scope; the plugin decides what to load.** A card's
  /// hook names the machine it is bound to, a tab's names every machine — and
  /// the same export gets both, so how much work a scope is worth is the
  /// plugin's call rather than a cadence the host imposes. It is what makes a
  /// reading lazy: `tick` pays for every machine on a timer, and this fires
  /// when somebody looks.
  ///
  /// Answers nothing. A plugin with something to draw sends it through
  /// `sb.ui.patch`, which is what lets a slow collection fill a page in as it
  /// lands instead of holding it blank until every machine has replied.
  ///
  /// A plugin that exports no `onHook` is not called at all.
  Future<void> hook(
    BigInt instance, {
    required String kind,
    required String contributionId,
    required List<String> granted,
    List<String> serverIds = const [],
  }) async {
    if (!hasExport(instance, _hookExport)) return;
    final instanceId = _instanceIds[instance];
    if (instanceId == null) return;

    // **The gate, and it belongs here rather than in the plugin.** The payload
    // has room for every server, and filling it for a plugin that never asked
    // for `server.list` would hand over the fleet through the back door — the
    // permission would then only govern `sb.server.list`, which is the call a
    // plugin makes rather than the knowledge it ends up with.
    //
    // Without the grant a surface's hook still fires; it carries the one
    // machine it is bound to, which the plugin was given at `init` anyway.
    final allowed = granted.contains('server.list')
        ? serverIds
        : serverIds.take(1).toList();

    final servers = [
      for (final id in allowed)
        {
          'server': bridge.handles.issue(instanceId, id),
          'name': _serverName?.call(id) ?? '',
        },
    ];

    try {
      await call(
        instance,
        _hookExport,
        jsonEncode({
          'kind': kind,
          'contribution': contributionId,
          'servers': servers,
        }),
      );
    } catch (e, s) {
      // A hook a plugin threw in is a plugin that will not collect, not a
      // surface that failed to open: the tree it already drew stays.
      Loggers.app.warning('Plugin hook $kind/$contributionId', e, s);
    }
  }

  static const _hookExport = 'onHook';

  /// How a server id becomes the display name a hook carries.
  ///
  /// Injected rather than read here, because this service is below the stores
  /// and a plugin's view of a server is the host's to decide — see
  /// `AppPluginHostOps.listServers`, which answers the same shape.
  String Function(String serverId)? _serverName;
  set serverNameLookup(String Function(String serverId)? lookup) =>
      _serverName = lookup;

  bool hasExport(BigInt instance, String export) =>
      _runtime?.hasExport(instance: instance, export_: export) ?? false;

  /// What the instance exports, or nothing for one that is gone.
  ///
  /// The runtime throws for an instance it has never had, which is the right
  /// answer to `call` and the wrong one to a question about what is loaded —
  /// "it is not there" is not a failure to report.
  List<String> exports(BigInt instance) {
    try {
      return _runtime?.exports(instance: instance) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Ends an instance and takes everything issued to it.
  ///
  /// Waits for the thread, so the requests it had outstanding are cancelled
  /// before this returns — which is what stops an answer arriving for an
  /// instance that is gone.
  Future<void> unload(BigInt instance) async {
    final instanceId = _instanceIds.remove(instance);
    await _runtime?.unload(instance: instance);
    if (instanceId != null) {
      bridge.handles.forget(instanceId);
      bridge.onPatch.remove(instanceId);
    }
  }

  /// What a status plugin wants run on [platform]. PLUGINS.md section 9.
  ///
  /// The same call the install page makes to show what will run, so what the
  /// user was shown and what runs cannot differ for want of asking twice.
  Future<ffi.PluginStatusCmd> statusCmd(BigInt instance, String platform) {
    final runtime = _runtime;
    if (runtime == null) throw StateError('the plugin runtime is not started');
    return runtime.statusCmd(instance: instance, platform: platform);
  }

  /// Hands a status plugin what its command printed.
  ///
  /// Checked on the Rust side before it gets here: a label longer than a label
  /// is cut, a `percent` outside 0..1 is dropped rather than clamped, and only
  /// a document that is not this shape at all is refused. A bad status plugin
  /// costs a row, not a card.
  Future<ffi.PluginStatusResult> statusParse(BigInt instance, String text) {
    final runtime = _runtime;
    if (runtime == null) throw StateError('the plugin runtime is not started');
    return runtime.statusParse(instance: instance, text: text);
  }

  /// How many requests the app has not answered. For diagnostics.
  int get outstanding => _runtime?.outstanding() ?? 0;

  /// Stops listening, without waiting for it.
  ///
  /// `RustStreamSink`'s stream comes from an `async*` generator sitting on a
  /// `ReceivePort`; cancelling its subscription returns a future that does not
  /// complete while the port is idle, so awaiting it hangs. There is nothing
  /// to wait for either: a sink stays open for the runtime's life, and what
  /// ends it is dropping the runtime.
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    _instanceIds.clear();
    _runtime = null;
  }
}
