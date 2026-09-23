import 'package:server_box/data/model/plugin/health.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/installed.dart';

/// The plugin report, as text somebody can paste. PLUGINS.md 8.4.
///
/// **Written to be sent to a plugin's author**, who has the code and not the
/// device. What they cannot work out for themselves is which of three things
/// happened — the collection did not run, the plugin threw, or what it drew
/// never landed — and every one of those looks like "the plugin does nothing"
/// from the user's side.
///
/// **Nothing in it is a value.** No command output, no configuration, no HTTP
/// body, no error message. A stage name and a failure tag are words this app
/// chose; the text after them belongs to the user's machine, and this is a
/// report written to be pasted in public. What the message said is on the
/// surface and in the log, which the person having the problem can read and
/// choose to send.
///
/// Plain text rather than JSON: it is read by a person first, in an issue, and
/// a wall of braces is not read at all.
class PluginReport {
  const PluginReport({
    required this.plugins,
    required this.health,
    required this.appVersion,
    required this.abi,
    required this.at,
  });

  final List<InstalledPlugin> plugins;
  final Map<String, PluginHealth> health;

  /// The app build, because a plugin's behaviour is half this app's.
  final String appVersion;

  /// The node and host-call set this build implements, which is what decides
  /// whether a plugin's version could have worked here at all.
  final int abi;

  final DateTime at;

  String write() {
    final out = StringBuffer()
      ..writeln('ServerBox plugin report')
      ..writeln('app $appVersion · plugin abi $abi · ${_time(at)}')
      ..writeln();

    if (plugins.isEmpty) {
      out.writeln('No plugins are installed.');
      return out.toString();
    }

    for (final plugin in plugins) {
      _writeOne(out, plugin);
      out.writeln();
    }
    // Said once, at the end, where somebody deciding whether to send it will
    // look. A report that does not say what it left out is one people paste
    // without reading.
    out.writeln(
      'Command output, configuration values and HTTP bodies are not collected.',
    );
    return out.toString();
  }

  void _writeOne(StringBuffer out, InstalledPlugin plugin) {
    final record = plugin.record;
    final manifest = plugin.manifest;
    out.writeln('${plugin.id} ${record.version}');
    out.writeln(
      '  built for   abi ${manifest.abi}'
      '${manifest.dataVersion == 0 ? '' : ', data v${manifest.dataVersion}'}',
    );
    out.writeln('  source      ${_source(record)}');
    out.writeln('  enabled     ${record.enabled ? 'yes' : 'no'}');
    // What the plugin may do, which is where a "permission denied" in the
    // lines below comes from — and the one list an author cannot guess, since
    // it is what the *user* agreed to rather than what the manifest asks.
    out.writeln(
      '  granted     '
      '${record.granted.isEmpty ? '(none)' : (record.granted.toList()..sort()).join(', ')}',
    );
    if (record.granted.length != manifest.permissions.length) {
      out.writeln(
        '  asks for    ${(manifest.permissions.toList()..sort()).join(', ')}',
      );
    }
    if (record.previous case final previous?) {
      out.writeln('  kept        ${previous.version}');
    }

    final one = health[plugin.id];
    if (one == null || one.isEmpty) {
      // Distinct from "it worked": a plugin whose surface has never been
      // opened has nothing recorded, and reading that as healthy is how a
      // report answers a question nobody asked.
      out.writeln('  activity    nothing recorded yet');
      return;
    }
    out.writeln('  last ok     ${_event(one.lastOk)}');
    out.writeln('  last fail   ${_event(one.lastFailure)}');
    if (one.failuresSinceOk > 0) {
      out.writeln('  failing     ${one.failuresSinceOk} in a row');
    }
  }

  static String _source(PluginInstall record) => switch (record.origin) {
    PluginOrigin.dev => 'a development directory',
    PluginOrigin.file => 'a package the user opened',
    // The address, which is a repository the author may not own — and is not
    // a secret: it is a public URL the user typed in or the app shipped.
    PluginOrigin.repo => record.repo!,
  };

  static String _event(PluginEvent? event) {
    if (event == null) return 'never';
    final failure = event.failure;
    return '${event.stage.name}'
        '${failure == null ? '' : ' ($failure)'}'
        ', ${_time(event.at)}, ${event.elapsed.inMilliseconds}ms';
  }

  /// To the second, in UTC.
  ///
  /// UTC because two reports from different people are compared against a
  /// release, not against each other's afternoons; to the second because
  /// milliseconds in a timestamp are noise beside a duration that is already
  /// printed.
  static String _time(DateTime at) {
    final utc = at.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
  }
}
