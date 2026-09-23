import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/plugin/health.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/plugin_health.dart';

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
      errorData = null,
      denied = null;

  const PluginAnswer.error(String kind, String message, {String? data})
    : ok = null,
      errorKind = kind,
      errorMessage = message,
      errorData = data,
      denied = null;

  const PluginAnswer.denied(String detail)
    : ok = null,
      errorKind = null,
      errorMessage = null,
      errorData = null,
      denied = detail;

  final String? ok;
  final String? errorKind;
  final String? errorMessage;

  /// A JSON object copied onto the `Error` beside `kind`, or null.
  ///
  /// For the failures that carry one more fact a plugin has to branch on. A
  /// cancelled `sb.server.exec` is the case that made it exist: whether the
  /// command was stopped on the server is not the same question as what kind
  /// of failure it was, and folding it into the kind string would make every
  /// plugin parse one.
  final String? errorData;

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
    PluginL10n Function(String pluginId)? strings,
  }) : _store = store ?? PluginKvStore.instance,
       _l10nOf = strings ?? _installedStrings;

  final PluginHostOps ops;

  /// A plugin's translations, for the strings it hands the app to *show*.
  ///
  /// Every other surface resolves `l10n.` where it draws — the renderer does
  /// it for every node — and `sb.ui.prompt` was the one place a plugin's
  /// string reached a widget without passing through it. So a dialog raised by
  /// a fully translated plugin came up titled `l10n.addTitle` over two boxes
  /// labelled `l10n.fieldWhen` and `l10n.fieldCommand`.
  ///
  /// Resolved here rather than in `AppPluginHostOps`, because this is where
  /// the plugin is known: the ops object is one object for every plugin, and
  /// `pluginId` arrives with the call.
  final PluginL10n Function(String pluginId) _l10nOf;

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

  /// Told after a host call for that instance has been answered.
  ///
  /// **Because the plugin cannot see an answer without being called.** The
  /// runtime delivers an outstanding call's result only while the instance is
  /// inside a call, so work a call deliberately did *not* wait for — a scan
  /// under `sb.server.cancel`'s key — lands in the runtime and sits there. The
  /// surface uses this to give the plugin a call when it is otherwise idle.
  final Map<String, void Function()> onAnswered = {};

  /// The runs a plugin may still stop, by the label it gave them.
  final runs = PluginRuns();

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
        final serverId = handles.resolve(instanceId, req['server']);
        if (serverId == null) {
          return PluginAnswer.badRequest('sb.server.exec: unknown server');
        }
        final script = req['script'];
        if (script is! String || script.isEmpty) {
          return PluginAnswer.badRequest('sb.server.exec: no `script`');
        }
        // A label the plugin picked, not a handle the host issued: what is
        // being stopped is usually not what the user pressed — a scan started
        // by a hook, stopped by a button several draws later — and those two
        // moments share no value.
        final key = req['cancelKey'];
        if (key != null && key is! String) {
          return PluginAnswer.badRequest('sb.server.exec: `cancelKey`');
        }
        final run = runs.start(instanceId, key as String?);
        // **Collection is its own stage.** "The plugin does nothing" is three
        // different failures — the machine did not answer, the plugin threw,
        // the tree did not land — and they look identical from a screenshot.
        // What is kept is which of the three and how long it took, never what
        // the command printed.
        final started = Stopwatch()..start();
        final PluginExecResult result;
        try {
          result = await ops.exec(
            serverId,
            script,
            timeout: _duration(req['timeoutMs']),
            cancel: run?.future,
          );
        } catch (e) {
          recordPluginEvent(
            pluginId,
            stage: PluginStage.exec,
            elapsed: started.elapsed,
            failure: pluginFailureTag(e),
          );
          rethrow;
        } finally {
          runs.finish(instanceId, key, run);
        }
        recordPluginEvent(
          pluginId,
          stage: PluginStage.exec,
          elapsed: started.elapsed,
          // A non-zero exit is the command's answer, not a failure of the
          // collection: the plugin asked and the machine replied. Only a run
          // that produced no answer at all is one.
          failure: switch (result.end) {
            PluginExecEnd.finished => null,
            PluginExecEnd.cancelled => 'cancelled',
            PluginExecEnd.timedOut => 'timeout',
          },
        );
        return _execAnswer(result);

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
        final started = Stopwatch()..start();
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
          recordPluginEvent(
            pluginId,
            stage: PluginStage.http,
            elapsed: started.elapsed,
            failure: pluginFailureTag(e),
          );
          return PluginAnswer.error('http', '$e');
        }
        recordPluginEvent(
          pluginId,
          stage: PluginStage.http,
          elapsed: started.elapsed,
          // The status is the server's answer rather than a failure to reach
          // it, and a plugin polling a BMC that says 401 until it logs in
          // would otherwise read as permanently broken.
        );
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
          //
          // **Not recorded.** Nobody is looking, which is the ordinary end of
          // a page closed mid-collection — writing it down would fill the
          // report with the one failure that means nothing went wrong.
          return PluginAnswer.error('no_surface', 'nothing is showing this');
        }
        apply((path: path, node: node));
        return const PluginAnswer.ok();

      case 'sb.ui.prompt':
        final title = req['title'];
        if (title is! String) {
          return PluginAnswer.badRequest('sb.ui.prompt: no `title`');
        }
        // Everything in this dialog is shown to the user, so everything in it
        // goes through the plugin's own strings — see [_strings].
        final l10n = _l10nOf(pluginId);
        final fields = <PluginPromptField>[];
        final rawFields = req['fields'];
        if (rawFields is List) {
          for (final raw in rawFields) {
            final field = PluginPromptField.fromJson(raw);
            if (field != null) fields.add(field.translated(l10n));
          }
        }
        // A body the plugin drew, which is the general case — `fields` is the
        // shorthand for a row of text boxes. Resolved as it is *drawn* rather
        // than here, like any other tree.
        final body = PluginNode.fromJson(req['node']);
        final answer = await ops.prompt(
          title: l10n.resolve(title),
          message: req['message'] is String
              ? l10n.resolve(req['message'] as String)
              : null,
          fields: fields,
          confirm: req['confirm'] is String
              ? l10n.resolve(req['confirm'] as String)
              : null,
          node: body,
          strings: l10n,
          sheet: req['as'] == 'sheet',
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
        // Shown to the user, so read in their language — see [_l10nOf].
        ops.toast(_l10nOf(pluginId).resolve(text), '${req['kind'] ?? 'info'}');
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

      case 'sb.server.cancel':
        final key = req['key'];
        if (key is! String || key.isEmpty) {
          return PluginAnswer.badRequest('sb.server.cancel: no `key`');
        }
        // Zero is an ordinary answer, not a failure: a Stop pressed just as
        // the scan came back is a key that names nothing, and the plugin's
        // page is already showing the result.
        return PluginAnswer.json({'stopped': runs.cancel(instanceId, key)});

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
        final serverId = handles.resolve(instanceId, req['server']);
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
        final serverId = handles.resolve(instanceId, req['server']);
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

  /// What `sb.server.exec` answers with, which for a run that was stopped is a
  /// rejection rather than an empty result.
  ///
  /// **Rejected on purpose.** A cancelled `du` has no output worth reading and
  /// what it does have is a prefix; answering `{code, stdout, stderr}` would
  /// make a plugin that does not check an extra field draw a partial reading
  /// as a complete one — wrong in the direction nobody notices. A rejection is
  /// the one shape a plugin cannot ignore by accident, and the SDK's
  /// `classify` turns it back into two words.
  ///
  /// `remote` is the fact the kind cannot carry: whether the command was
  /// stopped **on the server**, or only stopped being waited for.
  static PluginAnswer _execAnswer(PluginExecResult result) {
    final remote = result.stoppedCommand ? 'stopped' : 'running';
    final data = jsonEncode({'remote': remote});
    return switch (result.end) {
      PluginExecEnd.finished => PluginAnswer.json({
        'code': result.code,
        'stdout': result.stdout,
        'stderr': result.stderr,
      }),
      PluginExecEnd.cancelled => PluginAnswer.error(
        'cancelled',
        result.stoppedCommand
            ? 'the command was stopped on the server'
            : 'the app stopped waiting; the command may still be running',
        data: data,
      ),
      PluginExecEnd.timedOut => PluginAnswer.error(
        'timeout',
        result.stoppedCommand
            ? 'the command took too long and was stopped on the server'
            : 'the command took too long; it may still be running',
        data: data,
      ),
    };
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

/// The commands a plugin may still stop, by the label it gave them.
///
/// **Keyed by instance and then by label.** The instance is what makes the
/// label safe: two plugins — or two surfaces of one plugin — may both call
/// their scan `scan`, and a registry keyed by the label alone would let a
/// settings page stop a page's reading. The runtime cannot check this for the
/// app, because a label is a string the plugin made up rather than a handle
/// the host issued.
///
/// A label holds a *list*: a fleet-wide surface runs the same command on
/// twenty machines under one key, and stopping is stopping all of them.
class PluginRuns {
  final Map<String, Map<String, List<Completer<void>>>> _byInstance = {};

  /// Registers a run, or answers null when it carried no label.
  ///
  /// Null rather than a completer nothing can reach: a run with no `cancelKey`
  /// is one the plugin never intended to stop, and giving it a cancel future
  /// would mean holding a completer for the life of every command a plugin
  /// ever runs.
  Completer<void>? start(String instanceId, String? key) {
    if (key == null || key.isEmpty) return null;
    final run = Completer<void>();
    ((_byInstance[instanceId] ??= {})[key] ??= []).add(run);
    return run;
  }

  /// Takes a finished run out, whether it ended on its own or was stopped.
  void finish(String instanceId, Object? key, Completer<void>? run) {
    if (run == null || key is! String) return;
    final byKey = _byInstance[instanceId];
    final held = byKey?[key];
    if (held == null) return;
    held.remove(run);
    if (held.isEmpty) byKey!.remove(key);
    if (byKey!.isEmpty) _byInstance.remove(instanceId);
  }

  /// Stops every run this instance registered under [key], and says how many.
  int cancel(String instanceId, String key) {
    final held = _byInstance[instanceId]?[key];
    if (held == null || held.isEmpty) return 0;
    // A copy: completing one lets its `finally` run, which edits this list.
    final stopping = [...held];
    for (final run in stopping) {
      if (!run.isCompleted) run.complete();
    }
    return stopping.length;
  }

  /// Stops everything an instance had outstanding, for an unload.
  ///
  /// A surface that goes away is a surface nobody is waiting for. Without this
  /// its commands run to their own timeout, holding an SSH channel and — on a
  /// phone — whatever wakes the radio to read from it.
  void forget(String instanceId) {
    final byKey = _byInstance.remove(instanceId);
    if (byKey == null) return;
    for (final held in byKey.values) {
      for (final run in held) {
        if (!run.isCompleted) run.complete();
      }
    }
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

  /// The server [handle] names **for this instance**, or null for anything
  /// else — a handle nobody issued, one belonging to an instance that has
  /// gone, or one issued to a different instance.
  ///
  /// Keyed by instance rather than looked up in one shared map. The map is
  /// process-wide, so without the check a handle belonging to another instance
  /// — another *plugin* — resolved to its server. `sbm_plugin::scope` keeps a
  /// per-instance set and refuses such a call before it reaches here, which
  /// made this the second of two checks in the comment above it and the only
  /// one in fact.
  String? resolve(String instanceId, Object? handle) {
    if (handle is! String) return null;
    if (!(_issued[instanceId]?.contains(handle) ?? false)) return null;
    return _servers[handle];
  }

  void forget(String instanceId) {
    for (final handle in _issued.remove(instanceId) ?? const <String>{}) {
      _servers.remove(handle);
    }
    _bound.remove(instanceId);
  }

  static final _random = Random.secure();

  /// Not a server id, and not guessable from one — nor from the clock.
  ///
  /// The point of the handle is that a plugin cannot name a server it was not
  /// given, which a value derived from the id would undo. It used to be a
  /// base-36 timestamp plus a global counter, which is fully determined by
  /// when it was minted: a few thousand tries covers the space around a known
  /// moment. 128 bits from `Random.secure()` instead.
  static String _randomHandle() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return 'h${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}

/// The installed plugin's strings, which is where they are in the app.
///
/// A plugin that is not installed — a test's, one being read before its record
/// is written — has none, and its keys then show as themselves, which is the
/// same answer a missing translation gets everywhere else.
PluginL10n _installedStrings(String pluginId) =>
    PluginContributions.byId(pluginId)?.strings ?? PluginL10n.empty;
