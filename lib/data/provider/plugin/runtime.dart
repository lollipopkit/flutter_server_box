import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;

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

  bool hasExport(BigInt instance, String export) =>
      _runtime?.hasExport(instance: instance, export_: export) ?? false;

  List<String> exports(BigInt instance) =>
      _runtime?.exports(instance: instance) ?? const [];

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
