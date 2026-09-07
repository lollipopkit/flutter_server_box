import 'dart:convert';

import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/store/plugin.dart';

/// What the app answers one host call with.
///
/// Exactly one of the three, which is what `PluginRuntime.answer` takes:
///
/// - [ok] — the JSON the function answers with, `null` for the ones that
///   answer nothing.
/// - [errorKind] plus [errorMessage] — the app tried and could not. The plugin
///   sees a rejected promise it can catch.
/// - [denied] — the app refuses. The plugin cannot catch it.
class PluginAnswer {
  const PluginAnswer.ok([this.ok])
    : errorKind = null,
      errorMessage = null,
      denied = null;

  const PluginAnswer.error(String kind, String message)
    : ok = null,
      errorKind = kind,
      errorMessage = message,
      denied = null;

  const PluginAnswer.denied(String detail)
    : ok = null,
      errorKind = null,
      errorMessage = null,
      denied = detail;

  final String? ok;
  final String? errorKind;
  final String? errorMessage;
  final String? denied;

  /// A value the plugin gets as a resolved promise.
  factory PluginAnswer.json(Object? value) =>
      PluginAnswer.ok(jsonEncode(value));

  /// The request was not the shape this function takes.
  ///
  /// An error rather than a refusal: the plugin asked for something the app
  /// understands and got it wrong, which is a bug it can report — and a
  /// refusal is reserved for the app declining something it *did* understand.
  factory PluginAnswer.badRequest(String detail) =>
      PluginAnswer.error('bad_request', detail);
}

/// A subtree a plugin asked to replace, by JSON Pointer.
typedef PluginPatch = ({String path, PluginNode node});

/// Turns one `sb.*` request into an answer. PLUGINS.md section 4.3.
///
/// The protocol and nothing else: what each JSON shape means, what a malformed
/// one gets back, and which id a handle resolves to. The work itself is
/// [PluginHostOps], so what is here can be tested without an app under it —
/// and the encoding is the part with no other check on it, since the plugin
/// side of it is written in TypeScript.
///
/// **Nothing here checks a permission.** The runtime installs an ungranted
/// function as a throwing stub, records the refusal and fails the call
/// whatever the plugin answered, and it verifies a server handle and an HTTP
/// address before the request is ever sent here. A second, weaker copy of
/// those checks in Dart would be a second thing to keep right.
class PluginBridge {
  PluginBridge({
    required this.ops,
    required this.handles,
    PluginKvStore? store,
  }) : _store = store ?? PluginKvStore.instance;

  final PluginHostOps ops;

  /// Which server each opaque handle names, and which server each instance is
  /// bound to.
  final PluginServerHandles handles;

  final PluginKvStore _store;

  /// Where `sb.ui.patch` goes, registered by the surface showing the instance.
  ///
  /// A surface rather than the app: a patch replaces a subtree of *that*
  /// surface's last tree, and there is nothing sensible to do with one for a
  /// surface that is not on screen.
  final Map<String, void Function(PluginPatch patch)> onPatch = {};

  Future<PluginAnswer> answer({
    required String pluginId,
    required String instanceId,
    required String func,
    required String request,
  }) async {
    final Object? raw;
    try {
      raw = request.isEmpty ? null : jsonDecode(request);
    } catch (_) {
      return PluginAnswer.badRequest('$func: request is not JSON');
    }
    final req = raw is Map ? raw : const {};

    try {
      return await _dispatch(pluginId, instanceId, func, req);
    } catch (e) {
      // Whatever the app could not do, as a rejected promise rather than a
      // call that never returns. A plugin blocks until its request is
      // answered, so every path out of here has to answer.
      return PluginAnswer.error('io', '$e');
    }
  }

  Future<PluginAnswer> _dispatch(
    String pluginId,
    String instanceId,
    String func,
    Map req,
  ) async {
    switch (func) {
      case 'sb.server.exec':
        final serverId = handles.resolve(req['server']);
        if (serverId == null) {
          return PluginAnswer.badRequest('sb.server.exec: unknown server');
        }
        final script = req['script'];
        if (script is! String || script.isEmpty) {
          return PluginAnswer.badRequest('sb.server.exec: no `script`');
        }
        final result = await ops.exec(
          serverId,
          script,
          timeout: _duration(req['timeoutMs']),
        );
        return PluginAnswer.json({
          'code': result.code,
          'stdout': result.stdout,
          'stderr': result.stderr,
        });

      case 'sb.http.fetch':
        final url = req['url'];
        if (url is! String || url.isEmpty) {
          return PluginAnswer.badRequest('sb.http.fetch: no `url`');
        }
        // The runtime already refused an address outside the grant, a probe
        // carrying a body, and `via: "ssh"` without `server.stream`. What is
        // left here is the one case it cannot decide: this build has no way
        // to put a request through an SSH connection yet, and answering it
        // over the network instead would send it somewhere the plugin did not
        // ask for.
        final via = req['via'];
        if (via is String && via != 'direct') {
          return PluginAnswer.error(
            'unsupported',
            'sb.http.fetch: `via: "$via"` is not implemented in this build',
          );
        }
        final PluginFetchResult result;
        try {
          result = await ops.fetch(
            url: url,
            // Normalised here rather than in whoever sends it: the method is
            // part of the protocol, and a plugin writing `post` means the
            // same thing as one writing `POST`.
            method: req['method'] is String
                ? (req['method'] as String).toUpperCase()
                : 'GET',
            headers: _strings(req['headers']),
            body: req['body'] is String ? req['body'] as String : null,
            bodyEncoding: req['bodyEncoding'] == 'base64' ? 'base64' : 'utf8',
            pinSha256: req['pinSha256'] is String
                ? req['pinSha256'] as String
                : null,
            probeCert: req['probeCert'] == true,
            timeout: _duration(req['timeoutMs']),
          );
        } catch (e) {
          // The plugin sees a rejected promise it can catch. A refused
          // certificate arrives here like any other failure, and deliberately:
          // what the plugin can do about it — ask the user to review the new
          // one — is the same either way.
          return PluginAnswer.error('http', '$e');
        }
        return PluginAnswer.json({
          'status': result.status,
          'headers': result.headers,
          'body': result.body,
          'bodyEncoding': result.bodyEncoding,
          'cert': ?result.cert,
        });

      case 'sb.ui.patch':
        final path = req['path'];
        final node = PluginNode.fromJson(req['node']);
        if (path is! String || node == null) {
          return PluginAnswer.badRequest('sb.ui.patch: `path` and `node`');
        }
        final apply = onPatch[instanceId];
        if (apply == null) {
          // A surface that is not on screen has no tree to patch. An error
          // rather than a silent success: a plugin streaming a log should be
          // able to tell that nobody is watching.
          return PluginAnswer.error('no_surface', 'nothing is showing this');
        }
        apply((path: path, node: node));
        return const PluginAnswer.ok();

      case 'sb.ui.prompt':
        final title = req['title'];
        if (title is! String) {
          return PluginAnswer.badRequest('sb.ui.prompt: no `title`');
        }
        final fields = <PluginPromptField>[];
        final rawFields = req['fields'];
        if (rawFields is List) {
          for (final raw in rawFields) {
            final field = PluginPromptField.fromJson(raw);
            if (field != null) fields.add(field);
          }
        }
        final answer = await ops.prompt(
          title: title,
          message: req['message'] is String ? req['message'] as String : null,
          fields: fields,
          confirm: req['confirm'] is String ? req['confirm'] as String : null,
        );
        return PluginAnswer.json({
          'cancelled': answer.cancelled,
          'values': answer.values,
        });

      case 'sb.ui.pickServer':
        final serverId = await ops.pickServer();
        if (serverId == null) return PluginAnswer.json({'cancelled': true});
        // Issued here, which is the whole of "a plugin acts only on servers it
        // was given": the runtime refuses a handle it did not see issued, so a
        // plugin cannot make one up.
        return PluginAnswer.json({
          'server': handles.issue(instanceId, serverId),
        });

      case 'sb.ui.toast':
        final text = req['text'];
        if (text is! String) {
          return PluginAnswer.badRequest('sb.ui.toast: no `text`');
        }
        ops.toast(text, '${req['kind'] ?? 'info'}');
        return const PluginAnswer.ok();

      case 'sb.store.get':
        final scope = _scope(instanceId, req['scope']);
        if (scope == null) return _badScope(func, req['scope']);
        final key = req['key'];
        if (key is! String || key.isEmpty) {
          return PluginAnswer.badRequest('$func: no `key`');
        }
        return PluginAnswer.json({
          'value': _store.fetch(pluginId, key, serverId: scope.serverId),
        });

      case 'sb.store.set':
        final scope = _scope(instanceId, req['scope']);
        if (scope == null) return _badScope(func, req['scope']);
        final key = req['key'];
        if (key is! String || key.isEmpty) {
          return PluginAnswer.badRequest('$func: no `key`');
        }
        final value = req['value'];
        if (value == null) {
          _store.remove(pluginId, key, serverId: scope.serverId);
        } else {
          _store.put(pluginId, key, '$value', serverId: scope.serverId);
        }
        return const PluginAnswer.ok();

      case 'sb.store.list':
        final scope = _scope(instanceId, req['scope']);
        if (scope == null) return _badScope(func, req['scope']);
        final prefix = '${req['prefix'] ?? ''}';
        final keys = _store.keys(pluginId, serverId: scope.serverId);
        return PluginAnswer.json({
          'keys': [
            for (final key in keys)
              if (key.startsWith(prefix)) key,
          ],
        });

      case 'sb.diag.crumb':
        final name = req['name'];
        if (name is! String || name.isEmpty) {
          return PluginAnswer.badRequest('sb.diag.crumb: no `name`');
        }
        ops.crumb(pluginId, name, '${req['level'] ?? 'info'}');
        return const PluginAnswer.ok();

      case 'sb.server.list':
        final servers = await ops.listServers();
        return PluginAnswer.json({
          'servers': [
            for (final s in servers)
              // A handle rather than the id: it is meaningless outside this
              // instance, so one that leaked into a log or a plugin's own
              // storage names nothing.
              {'server': handles.issue(instanceId, s.id), 'name': s.name},
          ],
        });

      case 'sb.nav.openTerminal':
        final serverId = handles.resolve(req['server']);
        if (serverId == null) {
          return PluginAnswer.badRequest('sb.nav.openTerminal: unknown server');
        }
        final cmd = req['cmd'];
        if (cmd != null && cmd is! String) {
          return PluginAnswer.badRequest('sb.nav.openTerminal: `cmd`');
        }
        await ops.openTerminal(
          serverId,
          cmd: cmd as String?,
          // Absent means typed and not sent, which is the safer default and
          // the one the app's own callers use.
          run: req['run'] == true,
        );
        return const PluginAnswer.ok();

      case 'sb.nav.openServer':
        final serverId = handles.resolve(req['server']);
        if (serverId == null) {
          return PluginAnswer.badRequest('sb.nav.openServer: unknown server');
        }
        await ops.openServer(serverId);
        return const PluginAnswer.ok();

      case 'sb.nav.goTab':
        final tab = req['tab'];
        if (tab is! String || tab.isEmpty) {
          return PluginAnswer.badRequest('sb.nav.goTab: no `tab`');
        }
        await ops.goTab(tab);
        return const PluginAnswer.ok();

      case 'sb.clipboard.read':
        return PluginAnswer.json({'text': await ops.clipboardRead()});

      case 'sb.clipboard.write':
        final text = req['text'];
        if (text is! String) {
          return PluginAnswer.badRequest('sb.clipboard.write: no `text`');
        }
        await ops.clipboardWrite(text);
        return const PluginAnswer.ok();

      default:
        // A function this build has no case for. It reaches here only from a
        // runtime that installed it, so the two have drifted — which
        // `plugin_ffi_test.dart` checks by counting the table.
        return PluginAnswer.error('unknown_function', func);
    }
  }

  /// Which key-value namespace a request names.
  ///
  /// `server` on an instance bound to no server has nowhere to write. Refused
  /// rather than silently written globally: two servers' data in one namespace
  /// is a plugin reading the wrong machine's.
  ({String? serverId})? _scope(String instanceId, Object? raw) {
    switch (raw) {
      case 'global':
        return (serverId: null);
      case 'server':
        final bound = handles.boundServerOf(instanceId);
        return bound == null ? null : (serverId: bound);
      default:
        return null;
    }
  }

  PluginAnswer _badScope(String func, Object? raw) => PluginAnswer.badRequest(
    '$func: `scope` must be "global", or "server" on a bound instance'
    ' (got ${raw is String ? '"$raw"' : raw})',
  );

  static Duration? _duration(Object? ms) =>
      ms is num && ms > 0 ? Duration(milliseconds: ms.toInt()) : null;

  /// A JSON object read as a string map, dropping anything that is not one.
  ///
  /// Dropped rather than refused: a header whose value came out a number is a
  /// plugin's mistake in one entry, and failing the whole request over it
  /// gives no better answer than sending the rest.
  static Map<String, String> _strings(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
  }
}

/// The opaque names the host gives a plugin for the servers it may act on.
///
/// A handle is opaque to the plugin *and* meaningless to anyone else: it is
/// generated per instance, so two instances of one plugin never share one and
/// a handle that leaked out of a log names nothing. The runtime refuses a
/// handle it did not see issued (`sbm_plugin::scope`), so what is here is only
/// the mapping back.
class PluginServerHandles {
  PluginServerHandles({String Function()? generate})
    : _generate = generate ?? _randomHandle;

  final String Function() _generate;

  /// handle -> server id.
  final Map<String, String> _servers = {};

  /// instance -> the server it was loaded against, if any.
  final Map<String, String> _bound = {};

  /// instance -> the handles issued to it, so unloading takes them.
  final Map<String, Set<String>> _issued = {};

  /// Issues a handle for [serverId], or returns the one this instance already
  /// has for it.
  ///
  /// Reused rather than fresh per call, so a plugin picking the same server
  /// twice sees the same handle and can compare them — which is the only
  /// operation a plugin has on one.
  String issue(String instanceId, String serverId) {
    for (final handle in _issued[instanceId] ?? const <String>{}) {
      if (_servers[handle] == serverId) return handle;
    }
    final handle = _generate();
    _servers[handle] = serverId;
    (_issued[instanceId] ??= {}).add(handle);
    return handle;
  }

  /// The handle for the server an instance is bound to, issued at load.
  String bind(String instanceId, String serverId) {
    _bound[instanceId] = serverId;
    return issue(instanceId, serverId);
  }

  String? boundServerOf(String instanceId) => _bound[instanceId];

  /// The server [handle] names, or null for anything else — including a
  /// handle belonging to an instance that has gone.
  String? resolve(Object? handle) =>
      handle is String ? _servers[handle] : null;

  void forget(String instanceId) {
    for (final handle in _issued.remove(instanceId) ?? const <String>{}) {
      _servers.remove(handle);
    }
    _bound.remove(instanceId);
  }

  static var _counter = 0;

  /// Not a server id, and not guessable from one.
  ///
  /// The point of the handle is that a plugin cannot name a server it was not
  /// given, which a value derived from the id would undo.
  static String _randomHandle() {
    _counter++;
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'h${now.toRadixString(36)}${_counter.toRadixString(36)}';
  }
}
