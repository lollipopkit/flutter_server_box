part of 'viewer.dart';

/// A touch screen driven as a laptop's touchpad: one finger moves the
/// pointer, a tap clicks, two fingers tapped together right-click, and a tap
/// followed by a touch that moves drags.
///
/// Nothing here is what the finger's own buttons say. A finger on the glass
/// reports the primary button for as long as it is down; forwarding that made
/// every move a drag. What is pressed is decided from the gesture instead.
extension _TouchpadX on _RemoteDesktopViewerState {
  void _touchpadDown(
    PointerDownEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    _touches++;
    _maxTouches = math.max(_maxTouches, _touches);
    _touchAt[event.pointer] = event.localPosition;
    if (_touches > 1) {
      // A second finger: a right click or a scroll, not a tap and drag. The
      // tap before it was still a tap, and its click is owed.
      if (_tapDrag == _TapDrag.armed) {
        _tapDrag = _TapDrag.none;
        final point = _pointer.value;
        if (point != null) _click(session, point, 1);
      }
      return;
    }
    _touchMoved = false;

    final tap = _lastTap;
    if (_pendingClick != null &&
        tap != null &&
        event.timeStamp - tap.at <= kDoubleTapTimeout &&
        (event.localPosition - tap.position).distance <= kDoubleTapSlop) {
      // The second touch of a tap and drag, or of a double tap — which of
      // the two is up to what the finger does next. Nothing is sent yet, and
      // the first tap's click is now this gesture's to send.
      _pendingClick?.cancel();
      _pendingClick = null;
      _lastTap = null;
      _tapDrag = _TapDrag.armed;
      return;
    }
    _flushPendingClick(session);
  }

  void _touchpadMove(
    PointerMoveEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    if (session.viewOnly) return;
    final previous = _touchAt[event.pointer];
    if (previous == null) return;
    final delta = event.localPosition - previous;
    // A finger wanders a few points between landing and lifting. Until one
    // has gone further than a tap can, it is still a tap: the pointer stays
    // put, so the click lands where the pointer was drawn, and [_touchAt]
    // stays at the landing point, so crossing the slop moves the pointer by
    // the whole way the finger went. Counting any move over one point made
    // most real taps neither click nor arm a drag.
    //
    // Any finger counts. Two fingers moving together are a scroll, and
    // lifting them is not a two-finger tap — which was a right click at the
    // end of every scroll.
    if (!_touchMoved) {
      if (delta.distance <= kTouchSlop) return;
      _touchMoved = true;
    }
    _touchAt[event.pointer] = event.localPosition;
    // Only one finger moves the pointer; two are the scroll or the pinch the
    // gesture detector underneath handles.
    if (_touches != 1) return;

    final from = _pointerOr(transform);
    if (from == null) return;
    if (_tapDrag == _TapDrag.armed) {
      // The second touch has moved: a drag. Press where the pointer is,
      // before it goes anywhere.
      _tapDrag = _TapDrag.dragging;
      _buttons = 1;
      _sendPointer(session, from);
    }
    // Moved in desktop pixels, by as far as the finger moved across the
    // picture of the desktop — so the pointer keeps up with the finger at any
    // zoom, and stays where it was on the desktop when the zoom changes.
    _buttons = _tapDrag == _TapDrag.dragging ? 1 : 0;
    _sendPointer(
      session,
      transform.clampToDesktop(from + delta / transform.scale),
    );
  }

  void _touchpadUp(
    PointerUpEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    _touches = math.max(0, _touches - 1);
    _touchAt.remove(event.pointer);
    if (_touches > 0) return;
    final twoFingers = _maxTouches >= 2;
    final moved = _touchMoved;
    final tapDrag = _tapDrag;
    _maxTouches = 0;
    _touchMoved = false;
    _tapDrag = _TapDrag.none;
    if (session.viewOnly) return;
    final point = _pointerOr(transform);
    if (point == null) return;

    switch (tapDrag) {
      case _TapDrag.dragging:
        // The end of a tap and drag: let go where the pointer is.
        _buttons = 0;
        _sendPointer(session, point);
        return;
      case _TapDrag.armed:
        // Lifted without moving: a double tap, sent as the double click it
        // is — the first tap's click was held back for this.
        _click(session, point, 1);
        _click(session, point, 1);
        return;
      case _TapDrag.none:
    }
    if (moved) return;
    if (twoFingers) {
      _click(session, point, 4);
      return;
    }
    // Held back for as long as a second touch could still make this a tap
    // and drag. Clicking at once made the second touch's press the second
    // half of a double click, and the desktop took the pair as one — a window
    // maximised, an icon opened — and the drag never started.
    _lastTap = (at: event.timeStamp, position: event.localPosition);
    _pendingClick?.cancel();
    _pendingClick = Timer(kDoubleTapTimeout, () {
      if (mounted) _flushPendingClick(session);
    });
  }

  /// Sends the click a tap left waiting, now.
  void _flushPendingClick(RemoteDesktopSessionView session) {
    final pending = _pendingClick;
    if (pending == null) return;
    pending.cancel();
    _pendingClick = null;
    _lastTap = null;
    final point = _pointer.value;
    if (point != null) _click(session, point, 1);
  }

  void _click(RemoteDesktopSessionView session, Offset point, int buttons) {
    _buttons = buttons;
    _sendPointer(session, point);
    _buttons = 0;
    _sendPointer(session, point);
  }

  /// Forgets the gesture in progress, and any click still owed.
  void _resetTouchpad() {
    _pendingClick?.cancel();
    _pendingClick = null;
    _lastTap = null;
    _tapDrag = _TapDrag.none;
    _touches = 0;
    _maxTouches = 0;
    _touchMoved = false;
    _touchAt.clear();
  }
}

/// A tap and drag on the touchpad, as a laptop's does it: tap, then touch
/// again and move without lifting.
///
/// The first tap's click is held back for [kDoubleTapTimeout], because a
/// desktop reads a press soon after a click as a double click, whatever
/// follows it. Only the touchpad waits; a mouse click is sent as it happens.
enum _TapDrag {
  none,

  /// The second touch is down and has not moved: a drag if it moves, a
  /// double click if it lifts.
  armed,

  /// Pressed, and moving with the button held.
  dragging,
}
