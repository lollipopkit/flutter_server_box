import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/status_history.dart';

/// One way of obtaining a server's status.
///
/// Implementations own their transport and convert whatever it returns into
/// the app's [ServerStatus] and [StatusHistorySample], so nothing above this
/// line branches on how a server is reached. The two implementations start
/// from completely different data — SSH parses `SrvBoxSep`-delimited shell
/// output, monitor decodes its JSON API — and both land on the same shape.
///
/// Deliberately narrow: this covers *reading status*, not the SSH session
/// itself. Terminal, SFTP and port forwarding stay with `ServerNotifier`
/// because they are a different capability, declared through
/// [ServerCapabilities.shell] rather than by testing the runtime type.
abstract interface class ServerDataSource {
  /// What this transport can do. The UI reads it off `ServerState`.
  ServerCapabilities get capabilities;

  /// Fetches one sample and applies it onto [into], returning the result.
  ///
  /// Implementations mutate and return [into] rather than building a fresh
  /// status: the rolling state the app derives rates from (`cpu`, `netSpeed`,
  /// `diskIO`, `history`) lives on it and has to survive across refreshes.
  ///
  /// Throws on failure; the caller owns retry accounting and error mapping.
  Future<ServerStatus> fetchStatus(ServerStatus into);

  /// Trend points the source already holds, oldest first. Empty when
  /// [ServerCapabilities.storedHistory] is false.
  Future<List<StatusHistorySample>> fetchHistory({int minutes});

  /// Releases transport-owned resources. Safe to call more than once.
  void close();
}
