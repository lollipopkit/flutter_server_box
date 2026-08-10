import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

part 'session_requests.g.dart';

/// Which tab the app should be showing.
///
/// Set by anything that opens something living in a tab, and cleared by the
/// home page once it has moved. A request rather than a command because the
/// home page owns its page controller and the animation that goes with it.
@Riverpod(keepAlive: true)
class HomeTabRequest extends _$HomeTabRequest {
  @override
  AppTab? build() => null;

  void go(AppTab tab) => state = tab;

  void done() => state = null;
}

/// Servers waiting for a terminal.
///
/// A queue rather than a direct call because the tab that opens terminals may
/// not exist yet: tabs are built when first visited, so a request made from
/// the server list arrives before there is anything to receive it. The tab
/// drains this when it appears.
@Riverpod(keepAlive: true)
class TerminalRequests extends _$TerminalRequests {
  @override
  List<Spi> build() => const [];

  void add(Spi spi) => state = [...state, spi];

  void clear() => state = const [];
}

/// Servers waiting for a file browser. Same reasoning as [TerminalRequests].
@Riverpod(keepAlive: true)
class SftpRequests extends _$SftpRequests {
  @override
  List<Spi> build() => const [];

  void add(Spi spi) => state = [...state, spi];

  void clear() => state = const [];
}
