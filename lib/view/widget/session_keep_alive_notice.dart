import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/provider/session_keep_alive.dart';

/// Shows [SessionKeepAlive]'s notices as toasts: one per session about to
/// close, with its countdown and "Keep alive".
///
/// Wraps the app below the [ToastHost] (`MaterialApp.builder`), so it is
/// there whatever page is. It only reflects the provider: the toasts are
/// sticky and taken down when a session leaves the provider's state, so the
/// countdown that closes a session is the provider's, and a toast swiped away
/// early is a session that still closes when its countdown ends.
///
/// Sessions closed while the app was off screen ([SessionsClosedAway]) are
/// said once, as an ordinary toast each, when the app is back.
class SessionKeepAliveNotices extends ConsumerWidget {
  const SessionKeepAliveNotices({super.key, required this.child});

  final Widget child;

  static String tagOf(String id) => 'session-keep-alive:$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionsClosedAwayProvider, (_, closed) {
      if (closed.isEmpty) return;
      for (final expiry in closed) {
        Toast.show(
          l10n.remoteSessionClosedAway,
          body: '${expiry.name} · ${expiry.host}',
          level: ToastLevel.info,
        );
      }
      ref.read(sessionsClosedAwayProvider.notifier).clear();
    });
    ref.listen(sessionKeepAliveProvider, (previous, next) {
      final before = previous ?? const <String, SessionExpiry>{};
      for (final id in before.keys) {
        if (!next.containsKey(id)) Toast.dismiss(tagOf(id));
      }
      final keepAlive = ref.read(sessionKeepAliveProvider.notifier);
      for (final MapEntry(key: id, value: expiry) in next.entries) {
        // A deadline moving — the app coming back — is the same notice.
        if (before.containsKey(id)) continue;
        final title = '${expiry.name} · ${expiry.host}';
        Toast.show(
          title,
          tag: tagOf(id),
          duration: Duration.zero,
          level: ToastLevel.warn,
          leading: SessionKeepAliveCountdown(id: id, ring: true),
          content: _NoticeBody(id: id, title: title),
          action: ToastAction(
            label: l10n.remoteSessionKeepAlive,
            onTap: () => keepAlive.keepAlive(id),
          ),
        );
      }
    });
    return child;
  }
}

class _NoticeBody extends StatelessWidget {
  const _NoticeBody({required this.id, required this.title});

  final String id;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UIs.text13,
        ),
        const SizedBox(height: 2),
        SessionKeepAliveCountdown(id: id),
      ],
    );
  }
}

/// The seconds left before session [id] closes, as text or as a ring that
/// empties.
///
/// Worked out from the provider's deadline on every tick rather than counted
/// down here, so it cannot drift from what actually closes the session. With
/// no deadline — the app was off screen, and the countdown waits for it — it
/// shows what was left when it went.
class SessionKeepAliveCountdown extends ConsumerStatefulWidget {
  const SessionKeepAliveCountdown({
    super.key,
    required this.id,
    this.ring = false,
  });

  final String id;

  /// A ring rather than text.
  final bool ring;

  @override
  ConsumerState<SessionKeepAliveCountdown> createState() =>
      _SessionKeepAliveCountdownState();
}

class _SessionKeepAliveCountdownState
    extends ConsumerState<SessionKeepAliveCountdown> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Often enough that the number changes on the second, not up to a second
    // late; the ring is redrawn no more than that.
    _tick = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (deadline, paused) = ref.watch(
      sessionKeepAliveProvider.select(
        (s) => (s[widget.id]?.deadline, s[widget.id]?.paused),
      ),
    );
    const grace = SessionKeepAlive.grace;
    final left = deadline == null
        ? paused ?? grace
        : Duration(
            microseconds: math.max(
              0,
              deadline.difference(clock.now()).inMicroseconds,
            ),
          );
    if (widget.ring) {
      return SizedBox.square(
        dimension: 15,
        child: CircularProgressIndicator(
          value: left.inMicroseconds / grace.inMicroseconds,
          strokeWidth: 2,
        ),
      );
    }
    // Rounded up: "0" would be on screen for the last second the session is
    // still open.
    final seconds = (left.inMilliseconds / 1000).ceil();
    return Text(
      l10n.remoteSessionClosingIn(seconds),
      style: UIs.text12Grey,
    );
  }
}
