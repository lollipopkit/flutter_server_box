import 'package:server_box/data/model/server/server_private_info.dart';

/// Every string this install knows to be the user's, and what replaces it.
///
/// Precise rather than pattern-based, which is the whole point. A regex for
/// "things that look like a host" both misses — a machine called `nas` is not
/// a pattern — and overreaches, since a package name in a stack trace looks
/// like a domain. The app holds the actual records, so it can replace exactly
/// the strings that came out of them.
///
/// **Two readers want opposite things from the same text.** In the Logs page
/// the user needs to see which machine a line is about; in an issue, or in an
/// uploaded crash report, nobody may. Substitution is what separates them, and
/// it belongs here rather than at the point the line was written.
///
/// Numbered rather than hashed. A reader following one server through a log
/// needs to see the same token twice; they do not need it to mean anything.
abstract final class KnownIdentifiers {
  /// The identifiers of [servers], in the order they are stored.
  static Map<String, String> of(List<Spi> servers) {
    final out = <String, String>{};
    for (var i = 0; i < servers.length; i++) {
      final spi = servers[i];
      final n = i + 1;
      _add(out, spi.name, '<server-$n>');
      _add(out, spi.ssh?.ip, '<host-$n>');
      _add(out, spi.ssh?.user, '<user-$n>');
      // Both the address as configured and the host inside it: a message may
      // quote the whole URL, and a dio or socket error names the host alone.
      // Longest-first ordering in [substitute] keeps the two from colliding.
      _add(out, spi.monitorHttp?.addr, '<agent-$n>');
      _add(out, _hostOf(spi.monitorHttp?.addr), '<agent-$n>');
      _add(out, spi.bmc?.addr, '<bmc-$n>');
      _add(out, _hostOf(spi.bmc?.addr), '<bmc-$n>');
    }
    return out;
  }

  /// Applies [identifiers] to [text] in a single pass, longest match first.
  ///
  /// One pass, and that is the point rather than an optimisation. Replacing
  /// key by key means each pass can match inside a placeholder an earlier pass
  /// wrote: with servers named `prod-server` and `server`, the first becomes
  /// `<server-1>`, and the second's pass then rewrites the `server` inside it
  /// into `<<server-2>-1>`. The same happens to anything named `host`, `user`
  /// or `agent`. A scan over the original text can only match the original
  /// text.
  ///
  /// Longest first is still needed, for a different overlap: a machine called
  /// `db` and one called `db-prod` both match at the same position, and the
  /// short one winning would leave `<server-1>-prod` — still disclosing
  /// `-prod`, and no longer showing that two lines named different machines.
  /// Alternation in a Dart regex is ordered, so sorting decides it.
  static String substitute(String text, Map<String, String> identifiers) {
    if (identifiers.isEmpty || text.isEmpty) return text;
    final keys = identifiers.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(keys.map(RegExp.escape).join('|'));
    return text.replaceAllMapped(
      pattern,
      (m) => identifiers[m[0]] ?? m[0]!,
    );
  }

  /// Too short to substitute safely is left alone: a two-character name occurs
  /// inside ordinary words, and replacing it would corrupt the log rather than
  /// redact it. Such a name identifies little in any case.
  static void _add(Map<String, String> out, String? value, String replacement) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.length < 3) return;
    // First writer wins: the same string configured on two servers is one
    // machine as far as a reader is concerned, and renumbering it per record
    // would say it was two.
    out.putIfAbsent(trimmed, () => replacement);
  }

  /// The host inside a configured address, or null when there is not one.
  ///
  /// An address is stored as the user typed it — with a scheme for the agent
  /// and the BMC, sometimes with a port, sometimes neither. Anything that does
  /// not parse as a URL with a host contributes nothing here and is dropped;
  /// the address itself is already a key.
  static String? _hostOf(String? addr) {
    if (addr == null || addr.isEmpty) return null;
    final host = Uri.tryParse(addr.trim())?.host;
    return host == null || host.isEmpty ? null : host;
  }
}
