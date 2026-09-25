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
/// - The app off screen holds the countdown, and restarts it in full when the
///   app is back, so nothing closes behind a notice nobody could have seen. The
///   idle time itself keeps counting by the clock: a phone that froze the app
///   delays the timer, and the timer finding the time already passed shows the
///   notice at once. Leaving the app is not leaving a session — one on screen
///   when the app went stays on screen as far as this is concerned.

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
/// - The app off screen holds the countdown, and restarts it in full when the
///   app is back, so nothing closes behind a notice nobody could have seen. The
///   idle time itself keeps counting by the clock: a phone that froze the app
///   delays the timer, and the timer finding the time already passed shows the
///   notice at once. Leaving the app is not leaving a session — one on screen
///   when the app went stays on screen as far as this is concerned.
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
  /// - The app off screen holds the countdown, and restarts it in full when the
  ///   app is back, so nothing closes behind a notice nobody could have seen. The
  ///   idle time itself keeps counting by the clock: a phone that froze the app
  ///   delays the timer, and the timer finding the time already passed shows the
  ///   notice at once. Leaving the app is not leaving a session — one on screen
  ///   when the app went stays on screen as far as this is concerned.
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

String _$sessionKeepAliveHash() => r'30952c46b03e282e0e1114b1c5c7a52d53db5da7';

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
/// - The app off screen holds the countdown, and restarts it in full when the
///   app is back, so nothing closes behind a notice nobody could have seen. The
///   idle time itself keeps counting by the clock: a phone that froze the app
///   delays the timer, and the timer finding the time already passed shows the
///   notice at once. Leaving the app is not leaving a session — one on screen
///   when the app went stays on screen as far as this is concerned.

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
