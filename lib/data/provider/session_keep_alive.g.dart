// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_keep_alive.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Closes a remote session some time after it leaves the screen, rather than
/// the moment it does.
///
/// The one place this is decided, for every kind of session there is: the
/// remote desktop tab's, a guest's graphical console
/// (`RemoteDesktopSessions` registers both) and a guest's text console
/// (`VirtTextConsoles`). Each owner says what its session is called, how to
/// close it, and whether it is on screen; nothing here knows what a session
/// is.
///
/// - Off screen, a session waits [timeout] — `remoteSessionIdleTimeout`, read
///   when it is needed so a change applies to sessions already waiting. Never
///   (0) means it waits until it is closed.
/// - Then it is put in [state] for [grace]: the notice with the countdown and
///   "Keep alive". Keeping it starts a full [timeout] again; coming back to it
///   withdraws the notice; neither, and it is closed by its owner's own close.
/// - The app off screen holds the countdown, and carries on with what was left
///   when the app is back — never less than [graceOnReturn], so there is time
///   to read the notice and keep the session. Going away and back does not buy
///   a fresh countdown each time.
/// - A notice left off screen for another whole [timeout] is not waited on:
///   the session is closed then, and [SessionsClosedAway] says so once the app
///   is back. An app left in the background does not keep an idle session
///   open for good.
/// - The idle time itself keeps counting by the clock: a phone that froze the
///   app delays the timer, and the timer finding the time already passed shows
///   the notice at once. Leaving the app is not leaving a session — one on
///   screen when the app went stays on screen as far as this is concerned.

@ProviderFor(SessionKeepAlive)
final sessionKeepAliveProvider = SessionKeepAliveProvider._();

/// Closes a remote session some time after it leaves the screen, rather than
/// the moment it does.
///
/// The one place this is decided, for every kind of session there is: the
/// remote desktop tab's, a guest's graphical console
/// (`RemoteDesktopSessions` registers both) and a guest's text console
/// (`VirtTextConsoles`). Each owner says what its session is called, how to
/// close it, and whether it is on screen; nothing here knows what a session
/// is.
///
/// - Off screen, a session waits [timeout] — `remoteSessionIdleTimeout`, read
///   when it is needed so a change applies to sessions already waiting. Never
///   (0) means it waits until it is closed.
/// - Then it is put in [state] for [grace]: the notice with the countdown and
///   "Keep alive". Keeping it starts a full [timeout] again; coming back to it
///   withdraws the notice; neither, and it is closed by its owner's own close.
/// - The app off screen holds the countdown, and carries on with what was left
///   when the app is back — never less than [graceOnReturn], so there is time
///   to read the notice and keep the session. Going away and back does not buy
///   a fresh countdown each time.
/// - A notice left off screen for another whole [timeout] is not waited on:
///   the session is closed then, and [SessionsClosedAway] says so once the app
///   is back. An app left in the background does not keep an idle session
///   open for good.
/// - The idle time itself keeps counting by the clock: a phone that froze the
///   app delays the timer, and the timer finding the time already passed shows
///   the notice at once. Leaving the app is not leaving a session — one on
///   screen when the app went stays on screen as far as this is concerned.
final class SessionKeepAliveProvider
    extends $NotifierProvider<SessionKeepAlive, Map<String, SessionExpiry>> {
  /// Closes a remote session some time after it leaves the screen, rather than
  /// the moment it does.
  ///
  /// The one place this is decided, for every kind of session there is: the
  /// remote desktop tab's, a guest's graphical console
  /// (`RemoteDesktopSessions` registers both) and a guest's text console
  /// (`VirtTextConsoles`). Each owner says what its session is called, how to
  /// close it, and whether it is on screen; nothing here knows what a session
  /// is.
  ///
  /// - Off screen, a session waits [timeout] — `remoteSessionIdleTimeout`, read
  ///   when it is needed so a change applies to sessions already waiting. Never
  ///   (0) means it waits until it is closed.
  /// - Then it is put in [state] for [grace]: the notice with the countdown and
  ///   "Keep alive". Keeping it starts a full [timeout] again; coming back to it
  ///   withdraws the notice; neither, and it is closed by its owner's own close.
  /// - The app off screen holds the countdown, and carries on with what was left
  ///   when the app is back — never less than [graceOnReturn], so there is time
  ///   to read the notice and keep the session. Going away and back does not buy
  ///   a fresh countdown each time.
  /// - A notice left off screen for another whole [timeout] is not waited on:
  ///   the session is closed then, and [SessionsClosedAway] says so once the app
  ///   is back. An app left in the background does not keep an idle session
  ///   open for good.
  /// - The idle time itself keeps counting by the clock: a phone that froze the
  ///   app delays the timer, and the timer finding the time already passed shows
  ///   the notice at once. Leaving the app is not leaving a session — one on
  ///   screen when the app went stays on screen as far as this is concerned.
  SessionKeepAliveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionKeepAliveProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionKeepAliveHash();

  @$internal
  @override
  SessionKeepAlive create() => SessionKeepAlive();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, SessionExpiry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, SessionExpiry>>(value),
    );
  }
}

String _$sessionKeepAliveHash() => r'fc19bf55b712363ee27f61180cee18a32fab57d9';

/// Closes a remote session some time after it leaves the screen, rather than
/// the moment it does.
///
/// The one place this is decided, for every kind of session there is: the
/// remote desktop tab's, a guest's graphical console
/// (`RemoteDesktopSessions` registers both) and a guest's text console
/// (`VirtTextConsoles`). Each owner says what its session is called, how to
/// close it, and whether it is on screen; nothing here knows what a session
/// is.
///
/// - Off screen, a session waits [timeout] — `remoteSessionIdleTimeout`, read
///   when it is needed so a change applies to sessions already waiting. Never
///   (0) means it waits until it is closed.
/// - Then it is put in [state] for [grace]: the notice with the countdown and
///   "Keep alive". Keeping it starts a full [timeout] again; coming back to it
///   withdraws the notice; neither, and it is closed by its owner's own close.
/// - The app off screen holds the countdown, and carries on with what was left
///   when the app is back — never less than [graceOnReturn], so there is time
///   to read the notice and keep the session. Going away and back does not buy
///   a fresh countdown each time.
/// - A notice left off screen for another whole [timeout] is not waited on:
///   the session is closed then, and [SessionsClosedAway] says so once the app
///   is back. An app left in the background does not keep an idle session
///   open for good.
/// - The idle time itself keeps counting by the clock: a phone that froze the
///   app delays the timer, and the timer finding the time already passed shows
///   the notice at once. Leaving the app is not leaving a session — one on
///   screen when the app went stays on screen as far as this is concerned.

abstract class _$SessionKeepAlive
    extends $Notifier<Map<String, SessionExpiry>> {
  Map<String, SessionExpiry> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<Map<String, SessionExpiry>, Map<String, SessionExpiry>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, SessionExpiry>,
                Map<String, SessionExpiry>
              >,
              Map<String, SessionExpiry>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Sessions [SessionKeepAlive] closed while the app was off screen, reported
/// once it is back — they went without their notice ever being seen.

@ProviderFor(SessionsClosedAway)
final sessionsClosedAwayProvider = SessionsClosedAwayProvider._();

/// Sessions [SessionKeepAlive] closed while the app was off screen, reported
/// once it is back — they went without their notice ever being seen.
final class SessionsClosedAwayProvider
    extends $NotifierProvider<SessionsClosedAway, List<SessionExpiry>> {
  /// Sessions [SessionKeepAlive] closed while the app was off screen, reported
  /// once it is back — they went without their notice ever being seen.
  SessionsClosedAwayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionsClosedAwayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionsClosedAwayHash();

  @$internal
  @override
  SessionsClosedAway create() => SessionsClosedAway();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SessionExpiry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SessionExpiry>>(value),
    );
  }
}

String _$sessionsClosedAwayHash() =>
    r'bddbe62d6d34a8864271d1b442e5e4f1a3dc342b';

/// Sessions [SessionKeepAlive] closed while the app was off screen, reported
/// once it is back — they went without their notice ever being seen.

abstract class _$SessionsClosedAway extends $Notifier<List<SessionExpiry>> {
  List<SessionExpiry> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<SessionExpiry>, List<SessionExpiry>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<SessionExpiry>, List<SessionExpiry>>,
              List<SessionExpiry>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
