import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/ssh/terminal_session.dart';

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

/// Which tab is on screen right now.
///
/// [HomeTabRequest] is where something asks to be taken; this is where the
/// home page says where it ended up. The floating Agent needs it to stay out
/// of the way of the Agent tab, which is the better view of the same thing
/// whenever it is the one being looked at.
@Riverpod(keepAlive: true)
class CurrentHomeTab extends _$CurrentHomeTab {
  @override
  AppTab? build() => null;

  void update(AppTab tab) => state = tab;
}

/// The tab that is drawing something the window's chrome is in the way of.
///
/// One thing sets it: the globe. A sphere fills the column it is given, and the
/// bar over it and the navigation under it are two rows of controls around a
/// picture that *is* the page — so while it is up the tab takes the window and
/// carries its own way out.
///
/// Which tab rather than a bare flag, because a tab is kept alive behind the
/// others: the server tab goes on drawing a globe while somebody reads a
/// terminal, and the chrome has to be back for that one.
@Riverpod(keepAlive: true)
class ImmersiveTab extends _$ImmersiveTab {
  @override
  AppTab? build() => null;

  /// Says whether [tab] wants the window.
  ///
  /// A tab may only clear its own claim, so a page saying "not me" cannot take
  /// the window back from another that is asking for it.
  void update(AppTab tab, {required bool wants}) {
    if (wants) {
      state = tab;
    } else if (state == tab) {
      state = null;
    }
  }
}

/// A server waiting to be opened on the server tab.
///
/// A request rather than a call for two reasons. The tab may not exist yet —
/// tabs are built when first visited — and only the tab knows whether opening
/// something means selecting it beside the list or pushing a page over it.
///
/// One slot rather than a queue, unlike [TerminalRequests]: opening two
/// servers in a row means looking at the second one, not at both.
@Riverpod(keepAlive: true)
class ServerDetailRequest extends _$ServerDetailRequest {
  @override
  String? build() => null;

  void go(String serverId) => state = serverId;

  void done() => state = null;
}

/// A server waiting for a terminal, and what to put in it once it opens.
class TerminalRequest {
  const TerminalRequest(this.spi, {this.snippet, this.session});

  final Spi spi;

  /// Run as soon as the shell is ready. Null for a plain terminal.
  final Snippet? snippet;

  /// A shell that is already running, to be shown rather than started — a
  /// snippet begun in a dialog, carrying on where the user can watch it.
  final TerminalSession? session;
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
  List<TerminalRequest> build() => const [];

  void add(Spi spi, {Snippet? snippet, TerminalSession? session}) => state = [
    ...state,
    TerminalRequest(spi, snippet: snippet, session: session),
  ];

  void clear() => state = const [];
}

/// A standing request to close every terminal.
///
/// The tab that owns the sessions is the only thing that can close them, and
/// it is built when first visited — so this is a flag it drains, the same
/// arrangement [TerminalRequests] has, rather than a call. A request left
/// standing because that tab has never been built closes nothing when it
/// finally is, which is right: a tab nobody has opened has no sessions.
@Riverpod(keepAlive: true)
class TerminalCloseAllRequest extends _$TerminalCloseAllRequest {
  @override
  bool build() => false;

  void go() => state = true;

  void done() => state = false;
}

/// Servers waiting for a file browser. Same reasoning as [TerminalRequests].
@Riverpod(keepAlive: true)
class SftpRequests extends _$SftpRequests {
  @override
  List<Spi> build() => const [];

  void add(Spi spi) => state = [...state, spi];

  void clear() => state = const [];
}
