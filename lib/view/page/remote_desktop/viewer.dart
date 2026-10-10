import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;
import 'package:server_box/view/page/remote_desktop/frame_decoder.dart';
import 'package:server_box/view/page/remote_desktop/geometry.dart';
import 'package:server_box/view/page/remote_desktop/input.dart';

part 'cursor.dart';
part 'guide.dart';
part 'touchpad.dart';

/// Where the session on screen sits among the open ones, and what opens the
/// rest.
typedef RemoteDesktopSwitcher = ({
  int position,
  int total,
  VoidCallback onTap,
});

class RemoteDesktopViewer extends ConsumerStatefulWidget {
  const RemoteDesktopViewer({
    super.key,
    required this.sessionId,
    this.fullScreen = false,
    this.switcher,
    this.showName = true,
  });

  final String sessionId;
  final bool fullScreen;

  /// Makes the name in the toolbar the way to the other sessions.
  ///
  /// A single column has no bar above the viewer, so the switcher goes here
  /// rather than in a second row repeating the name. Null leaves the name a
  /// label.
  final RemoteDesktopSwitcher? switcher;

  /// False where the page around it already names the session — the
  /// virtualization guest's console — so the bar keeps only its state.
  final bool showName;

  /// The layer the pointer is drawn on, for tests to find.
  @visibleForTesting
  static const cursorKey = ValueKey('remote-desktop-cursor');

  /// Stands in for the platform when deciding whether touches drive a
  /// touchpad pointer. The test host is a desktop, and that path is the one
  /// that needs covering.
  @visibleForTesting
  static bool? debugTouchScreenOverride;

  @override
  ConsumerState<RemoteDesktopViewer> createState() =>
      _RemoteDesktopViewerState();
}

class _RemoteDesktopViewerState extends ConsumerState<RemoteDesktopViewer> {
  late final RemoteDesktopFrameDecoder _frame;
  late final FocusNode _keyboardFocus;
  late final FocusNode _imeFocus;
  late final TextEditingController _imeController;
  RemoteDesktopInputController? _input;
  RemoteDesktopScaleMode _scaleMode = RemoteDesktopScaleMode.fit;
  double _customScale = 1;
  Offset _pan = Offset.zero;

  /// The canvas's size while no soft keyboard is open: what it keeps while
  /// one is.
  Size? _restingViewport;

  /// While a keyboard is open: the layout at rest, the height left above the
  /// keyboard, and the shift it was drawn with.
  (RemoteDesktopViewportTransform, double, double)? _keyboardAtRest;
  int _buttons = 0;
  int _touches = 0;
  int _maxTouches = 0;
  bool _touchMoved = false;
  /// Where each finger on the touchpad was last counted from: where it landed
  /// until the gesture has moved, then where it was on its last move. Per
  /// finger, so a finger left down when another lifts carries on from its own
  /// position rather than the other's.
  final _touchAt = <int, Offset>{};

  /// The finger the direct path is following; the rest are ignored.
  int? _directPointer;

  /// The last one-finger tap on the touchpad, whose click has not been sent
  /// yet: when, and where the finger was. See [_TapDrag].
  ({Duration at, Offset position})? _lastTap;

  /// Sends [_lastTap]'s click once no second touch has come for it. Non-null
  /// for exactly as long as that click is owed.
  Timer? _pendingClick;

  /// A finger held still: a right click once [kLongPressTimeout] has passed,
  /// as in most VNC clients (#1640). Cancelled by anything else it does.
  Timer? _longPress;

  /// The finger down was held long enough to right-click: lifting it sends
  /// nothing more.
  bool _longPressed = false;

  /// Where the finger [_longPress] waits on landed.
  Offset? _longPressAt;

  _TapDrag _tapDrag = _TapDrag.none;
  _TouchMode _touchMode = _TouchMode.trackpad;
  double _scaleStart = 1;
  Timer? _resizeTimer;
  Size? _lastResizeViewport;

  /// What the walkthrough points at. See [_GuideX].
  final _canvasKey = GlobalKey();
  final _viewOnlyKey = GlobalKey();
  final _keyboardKey = GlobalKey();
  final _moreKey = GlobalKey();
  bool _guideHandled = false;

  /// Where the remote pointer is, in desktop pixels. See [_CursorX].
  final _pointer = ValueNotifier<Offset?>(null);

  /// What drove the pointer last, which decides whether it is drawn here.
  ui.PointerDeviceKind? _inputKind;
  (int, int)? _serverCursorAt;
  Uint8List? _cursorRgba;
  ui.Image? _cursorImage;

  @override
  void initState() {
    super.initState();
    _frame = RemoteDesktopFrameDecoder();
    _keyboardFocus = FocusNode(onKeyEvent: _onKeyEvent);
    _keyboardFocus.addListener(_onFocusChanged);
    _imeFocus = FocusNode();
    _imeController = TextEditingController();
    _pointer.addListener(_onPointerMoved);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _keyboardFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant RemoteDesktopViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId == widget.sessionId) return;
    _input?.releaseAll();
    _input = null;
    _resetCursor();
    // Owed to the session that was showing, not to this one.
    _resetTouchpad();
    _endLongPress();
    _directPointer = null;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _lastResizeViewport = null;
    _frame.reset();
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    _pendingClick?.cancel();
    _longPress?.cancel();
    _input?.releaseAll();
    _keyboardFocus.removeListener(_onFocusChanged);
    _keyboardFocus.dispose();
    _imeFocus.dispose();
    _imeController.dispose();
    _frame.dispose();
    _pointer.removeListener(_onPointerMoved);
    _pointer.dispose();
    _cursorImage?.dispose();
    if (widget.fullScreen && isMobile) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  /// A pointer that moves under the keyboard brings the picture along. The
  /// canvas is laid out again only for that: a desktop with nothing changing
  /// on it sends no frame that would.
  void _onPointerMoved() {
    final atRest = _keyboardAtRest;
    if (atRest == null) return;
    final (transform, visible, drawn) = atRest;
    final shift = remoteDesktopKeyboardShift(
      transform,
      visibleHeight: visible,
      pointer: _pointer.value,
    );
    if (shift == drawn) return;
    // Also set while building (`_placePointer`): not a time to mark dirty.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// `setState` for the parts of this state in extensions, which may not call
  /// a protected member themselves.
  void _update(VoidCallback change) => setState(change);

  void _onFocusChanged() {
    if (!_keyboardFocus.hasFocus) _input?.releaseAll();
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    final session = ref.read(remoteDesktopSessionsProvider).byId(widget.sessionId);
    if (session == null || session.viewOnly) return KeyEventResult.ignored;
    _ensureInput(session);
    return _input!.handle(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  void _ensureInput(RemoteDesktopSessionView session) {
    if (_input?.protocol == session.profile.protocol) return;
    final notifier = ref.read(remoteDesktopSessionsProvider.notifier);
    _input = RemoteDesktopInputController(
      protocol: session.profile.protocol,
      sendKey: (code, down, extended) => notifier.sendKey(
        session.id,
        code,
        down,
        extended: extended,
      ),
      sendText: (text) => notifier.sendUnicodeText(session.id, text),
      releaseRemoteKeys: () => notifier.releaseAllKeys(session.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(
      remoteDesktopSessionsProvider.select((state) => state.byId(widget.sessionId)),
    );
    if (session == null) return const SizedBox.shrink();
    _ensureInput(session);
    _syncCursor(session);
    _scheduleGuide(session);
    final pixels = session.frameBgra;
    if (pixels != null && session.width > 0 && session.height > 0) {
      _frame.submit(
        pixels: pixels,
        width: session.width,
        height: session.height,
        sequence: session.frameSequence,
      );
    }
    // Material rather than a bare colour: the hidden IME field below needs
    // one, and a host page is not obliged to provide it.
    return Material(
      color: Colors.black,
      child: Column(
        children: [
          if (!widget.fullScreen || !isMobile) _toolbar(session),
          Expanded(child: _canvas(session)),
          _imeField(session),
        ],
      ),
    );
  }

  /// Every tab's bar — see [SwitcherBar].
  Widget _toolbar(RemoteDesktopSessionView session) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(remoteDesktopSessionsProvider.notifier);
    final connected = session.connectionState ==
        ffi.RemoteDesktopConnectionState.connected;
    final input = connected && !session.viewOnly;
    final switcher = widget.switcher;

    return Material(
      color: scheme.surface,
      child: SwitcherBar(
        switcher: widget.showName
            ? SessionSwitcherLabel(
                name: session.profile.name,
                position: switcher?.position,
                total: switcher?.total ?? 0,
                leading: _connectionDot(session.connectionState),
                onTap: switcher?.onTap,
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 17),
                  child: _connectionDot(session.connectionState),
                ),
              ),
        // Most needed first: what does not fit folds into the menu from the
        // end.
        actions: [
          BarAction(
            key: _viewOnlyKey,
            icon: session.viewOnly ? Icons.visibility : Icons.mouse,
            label: session.viewOnly
                ? l10n.remoteDesktopDisableViewOnly
                : l10n.remoteDesktopViewOnly,
            // On is the exception: input is not reaching the desktop.
            color: session.viewOnly ? scheme.primary : null,
            onTap: () => _setViewOnly(session, !session.viewOnly),
          ),
          BarAction(
            key: _keyboardKey,
            icon: Icons.keyboard,
            label: l10n.remoteDesktopShowKeyboard,
            onTap: session.viewOnly ? null : _showKeyboard,
          ),
          _scaleAction(),
          BarAction(
            icon: widget.fullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            label: widget.fullScreen
                ? l10n.remoteDesktopExitFullScreen
                : l10n.remoteDesktopFullScreen,
            onTap: _toggleFullScreen,
          ),
          BarAction(
            icon: Icons.content_paste,
            label: l10n.remoteDesktopSendClipboardText,
            onTap: input ? () => _sendClipboard(session) : null,
          ),
        ],
        menuKey: _moreKey,
        menuLabel: l10n.remoteDesktopMoreControls,
        menu: () => [
          ContextMenuAction(
            text: l10n.remoteDesktopSendCtrlAltDelete,
            icon: Icons.keyboard_command_key,
            enabled: input,
            onTap: () => _sendCtrlAltDelete(session),
          ),
          if (isMobile)
            ContextMenuAction(
              text: _touchMode == _TouchMode.trackpad
                  ? l10n.remoteDesktopUseDirectPointer
                  : l10n.remoteDesktopUseTouchpadPointer,
              icon: _touchMode == _TouchMode.trackpad
                  ? Icons.touch_app
                  : Icons.mouse,
              onTap: _toggleTouchMode,
            ),
          ContextMenuAction(
            text: l10n.remoteDesktopReconnect,
            icon: Icons.refresh,
            onTap: () => notifier.reconnect(session.id),
          ),
          ContextMenuAction(
            text: l10n.remoteDesktopCloseSession,
            icon: Icons.link_off,
            destructive: true,
            onTap: () => _closeSession(session),
          ),
        ],
      ),
    );
  }

  /// Turning input off lets go of everything held first: the desktop is not
  /// sent anything once it is off, so a button down then stayed down there.
  void _setViewOnly(RemoteDesktopSessionView session, bool viewOnly) {
    if (viewOnly) {
      _input?.releaseAll();
      _resetTouchpad();
      _endLongPress();
      _directPointer = null;
      final point = _pointer.value;
      if (_buttons != 0 && point != null) {
        _buttons = 0;
        _sendPointer(session, point);
      }
    }
    ref
        .read(remoteDesktopSessionsProvider.notifier)
        .setViewOnly(session.id, viewOnly);
  }

  void _setScaleMode(RemoteDesktopScaleMode mode) => setState(() {
    _scaleMode = mode;
    _pan = Offset.zero;
  });

  /// Fit, actual size and the zoom steps are one choice, so one button: its
  /// icon says which is in effect, the menu ticks it.
  BarAction _scaleAction() {
    final l10n = context.l10n;
    ContextMenuAction item(
      String text,
      bool current,
      VoidCallback onTap,
    ) => ContextMenuAction(text: text, checked: current, onTap: onTap);
    final custom = _scaleMode == RemoteDesktopScaleMode.custom;
    return BarAction.menu(
      label: switch (_scaleMode) {
        RemoteDesktopScaleMode.fit => l10n.remoteDesktopFitToWindow,
        RemoteDesktopScaleMode.actual => l10n.remoteDesktopActualSize,
        RemoteDesktopScaleMode.custom =>
          '${l10n.remoteDesktopZoom} ${(_customScale * 100).round()}%',
      },
      icon: switch (_scaleMode) {
        RemoteDesktopScaleMode.fit => Icons.fit_screen,
        RemoteDesktopScaleMode.actual => Icons.crop_free,
        RemoteDesktopScaleMode.custom => Icons.zoom_in,
      },
      menu: () => [
        item(
          l10n.remoteDesktopFitToWindow,
          _scaleMode == RemoteDesktopScaleMode.fit,
          () => _setScaleMode(RemoteDesktopScaleMode.fit),
        ),
        item(
          l10n.remoteDesktopActualSize,
          _scaleMode == RemoteDesktopScaleMode.actual,
          () => _setScaleMode(RemoteDesktopScaleMode.actual),
        ),
        for (final zoom in const [0.5, 0.75, 1.25, 1.5, 2.0])
          item(
            '${(zoom * 100).round()}%',
            custom && _customScale == zoom,
            () => setState(() {
              _customScale = zoom;
              _scaleMode = RemoteDesktopScaleMode.custom;
            }),
          ),
      ],
    );
  }

  Widget _connectionDot(ffi.RemoteDesktopConnectionState state) {
    final l10n = context.l10n;
    final color = switch (state) {
      ffi.RemoteDesktopConnectionState.connected => Colors.green,
      ffi.RemoteDesktopConnectionState.connecting ||
      ffi.RemoteDesktopConnectionState.reconnecting => Colors.orange,
      ffi.RemoteDesktopConnectionState.disconnected => Colors.red,
    };
    return Tooltip(
      message: switch (state) {
        ffi.RemoteDesktopConnectionState.connected =>
          l10n.remoteDesktopConnected,
        ffi.RemoteDesktopConnectionState.connecting =>
          l10n.remoteDesktopConnecting,
        ffi.RemoteDesktopConnectionState.reconnecting =>
          l10n.remoteDesktopReconnecting,
        ffi.RemoteDesktopConnectionState.disconnected =>
          l10n.remoteDesktopDisconnected,
      },
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Future<void> _sendClipboard(RemoteDesktopSessionView session) async {
    if (session.profile.protocol == RemoteDesktopProtocol.vnc) {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (text != null && text.runes.any((rune) => rune > 0xff)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.remoteDesktopVncClipboardLatin1Only)),
          );
        }
        return;
      }
    }
    await ref.read(remoteDesktopSessionsProvider.notifier).sendClipboard(session.id);
  }

  void _showKeyboard() {
    _imeFocus.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  void _toggleTouchMode() => setState(() {
    _touchMode = _touchMode == _TouchMode.trackpad
        ? _TouchMode.direct
        : _TouchMode.trackpad;
  });

  Future<void> _closeSession(RemoteDesktopSessionView session) async {
    final notifier = ref.read(remoteDesktopSessionsProvider.notifier);
    if (widget.fullScreen && mounted) Navigator.of(context).pop();
    await notifier.close(session.id);
  }

  void _sendCtrlAltDelete(RemoteDesktopSessionView session) {
    final notifier = ref.read(remoteDesktopSessionsProvider.notifier);
    final keys = session.profile.protocol == RemoteDesktopProtocol.rdp
        ? const [
            RemoteDesktopKey(0x1d),
            RemoteDesktopKey(0x38),
            RemoteDesktopKey(0x53, extended: true),
          ]
        : const [
            RemoteDesktopKey(0xffe3),
            RemoteDesktopKey(0xffe9),
            RemoteDesktopKey(0xffff),
          ];
    for (final key in keys) {
      notifier.sendKey(session.id, key.code, true, extended: key.extended);
    }
    for (final key in keys.reversed) {
      notifier.sendKey(session.id, key.code, false, extended: key.extended);
    }
  }

  Future<void> _toggleFullScreen() async {
    if (widget.fullScreen) {
      Navigator.of(context).pop();
      return;
    }
    if (isMobile) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: RemoteDesktopViewer(
              sessionId: widget.sessionId,
              fullScreen: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _imeField(RemoteDesktopSessionView session) => SizedBox(
    width: 1,
    height: 1,
    child: Opacity(
      opacity: 0,
      child: TextField(
        focusNode: _imeFocus,
        controller: _imeController,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (text) {
          if (text.isNotEmpty && !session.viewOnly) {
            ref
                .read(remoteDesktopSessionsProvider.notifier)
                .sendUnicodeText(session.id, text);
          }
          _imeController.clear();
        },
      ),
    ),
  );

  Widget _canvas(RemoteDesktopSessionView session) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        _scheduleResize(session, viewport);
        final desktop = Size(session.width.toDouble(), session.height.toDouble());
        // A soft keyboard shrinks the canvas — the scaffolds above resize for
        // it — and a picture fitted to the strip left above it was tiny
        // (#1639). Laid out at the size it had before instead, moved up just
        // enough to keep the pointer in sight; the keyboard covers the rest.
        // Asked of the `View`, as in [_scheduleResize].
        final keyboard = View.of(context).viewInsets.bottom > 0;
        if (!keyboard) _restingViewport = viewport;
        final resting = _restingViewport;
        final keepSize = keyboard &&
            resting != null &&
            resting.width == viewport.width &&
            resting.height > viewport.height;
        RemoteDesktopViewportTransform layout(Offset pan) =>
            RemoteDesktopViewportTransform.calculate(
              viewport: keepSize ? resting : viewport,
              desktop: desktop,
              mode: _scaleMode,
              customScale: _customScale,
              pan: pan,
            );
        var transform = layout(_pan);
        _keyboardAtRest = null;
        if (keepSize) {
          final shift = remoteDesktopKeyboardShift(
            transform,
            visibleHeight: viewport.height,
            pointer: _pointerOr(transform),
          );
          // Kept, so a pointer moving with nothing else changing can ask for
          // another shift — see [_onPointerMoved].
          _keyboardAtRest = (transform, viewport.height, shift);
          if (shift > 0) transform = layout(_pan + Offset(0, -shift));
        }
        _placePointer(transform);
        return Focus(
          focusNode: _keyboardFocus,
          child: Listener(
            key: _canvasKey,
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _pointerDown(event, transform, session),
            onPointerMove: (event) => _pointerMove(event, transform, session),
            onPointerUp: (event) => _pointerUp(event, transform, session),
            onPointerHover: (event) => _pointerHover(event, transform, session),
            onPointerCancel: (event) => _pointerCancel(event, session),
            onPointerSignal: (event) => _pointerSignal(event, transform, session),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _scaleStart = _scaleMode == RemoteDesktopScaleMode.custom
                    ? _customScale
                    : transform.scale;
              },
              onScaleUpdate: (details) {
                if (details.pointerCount < 2) return;
                if ((details.scale - 1).abs() > 0.02) {
                  setState(() {
                    _customScale = (_scaleStart * details.scale).clamp(0.1, 8.0);
                    _scaleMode = RemoteDesktopScaleMode.custom;
                  });
                } else if (!session.viewOnly) {
                  final point = _pointerOr(transform);
                  if (point != null) {
                    ref.read(remoteDesktopSessionsProvider.notifier).sendWheel(
                      session.id,
                      point.dx.round(),
                      point.dy.round(),
                      deltaX: (-details.focalPointDelta.dx * 8).round(),
                      deltaY: (-details.focalPointDelta.dy * 8).round(),
                    );
                  }
                }
              },
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _frame,
                  builder: (_, _) => Stack(
                    children: [
                      const Positioned.fill(child: ColoredBox(color: Colors.black)),
                      if (_frame.image case final image?)
                        Positioned.fromRect(
                          rect: transform.destination,
                          child: RawImage(
                            image: image,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.low,
                          ),
                        )
                      else
                        _status(session),
                      if (_frame.image != null && _drawsCursor)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: RemoteDesktopViewer.cursorKey,
                              painter: _CursorPainter(
                                pointer: _pointer,
                                transform: transform,
                                cursor: session.cursor,
                                image: _cursorImage,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _status(RemoteDesktopSessionView session) {
    final text = session.certificate != null
        ? l10n.remoteDesktopCertificateRequired
        : session.error ??
              switch (session.connectionState) {
                ffi.RemoteDesktopConnectionState.connecting =>
                  l10n.remoteDesktopConnecting,
                ffi.RemoteDesktopConnectionState.reconnecting =>
                  l10n.remoteDesktopReconnectAttempt(session.reconnectAttempt),
                ffi.RemoteDesktopConnectionState.connected =>
                  l10n.remoteDesktopWaiting,
                ffi.RemoteDesktopConnectionState.disconnected =>
                  l10n.remoteDesktopDisconnected,
              };
    // Retrying is otherwise two taps deep in the toolbar's menu, and the one
    // thing to do once automatic retries have given up.
    final retry =
        session.certificate == null &&
        session.connectionState ==
            ffi.RemoteDesktopConnectionState.disconnected;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (retry) ...[
              const SizedBox(height: 13),
              TextButton.icon(
                onPressed: () => unawaited(
                  ref
                      .read(remoteDesktopSessionsProvider.notifier)
                      .reconnect(session.id),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.remoteDesktopReconnect),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _scheduleResize(RemoteDesktopSessionView session, Size viewport) {
    if (session.profile.protocol != RemoteDesktopProtocol.rdp ||
        viewport.isEmpty ||
        viewport == _lastResizeViewport) {
      return;
    }
    // A soft keyboard shrinks the canvas by its height — the scaffolds above
    // resize for it — and that is not a new screen. Sending it squashed every
    // window on the remote desktop to the strip above the keyboard, then
    // stretched them back when it closed. [_lastResizeViewport] is left as
    // it was, so the canvas returning to that size afterwards sends nothing.
    //
    // Asked of the `View`: a `Scaffold` takes the inset it resized for out of
    // the `MediaQuery` its body sees, so below one this reads zero.
    if (View.of(context).viewInsets.bottom > 0) return;
    _lastResizeViewport = viewport;
    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final ratio = MediaQuery.devicePixelRatioOf(context);
      final width = (viewport.width * ratio).round().clamp(1, 8192);
      final height = (viewport.height * ratio).round().clamp(1, 8192);
      const mmPerInch = 25.4;
      const assumedDpi = 96.0;
      ref.read(remoteDesktopSessionsProvider.notifier).resize(
        session.id,
        width,
        height,
        scaleFactor: (ratio * 100).round().clamp(100, 500),
        physicalWidthMm: (width / assumedDpi * mmPerInch).round(),
        physicalHeightMm: (height / assumedDpi * mmPerInch).round(),
      );
    });
  }

  bool get _touchScreen =>
      RemoteDesktopViewer.debugTouchScreenOverride ?? isMobile;

  /// Whether [event] moves the pointer the way a laptop's touchpad does,
  /// rather than pressing where it lands. See [_TouchpadX].
  bool _touchpad(PointerEvent event) =>
      _touchScreen &&
      event.kind == ui.PointerDeviceKind.touch &&
      _touchMode == _TouchMode.trackpad;

  // Two kinds of input, and nothing shared between them but the pointer they
  // move. A touchpad has to guess — whether a tap is a click, whether the
  // next touch is a drag — and waits to find out; a mouse, a pen or a direct
  // finger says what its buttons are doing, and is forwarded as it says it.

  void _pointerDown(
    PointerDownEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    _keyboardFocus.requestFocus();
    _noteInputKind(event.kind);
    if (session.viewOnly) return;
    if (_touchpad(event)) return _touchpadDown(event, transform, session);
    _flushPendingClick(session);
    // One finger at a time. The others are a pinch or a scroll, which the
    // gesture detector underneath handles.
    if (event.kind == ui.PointerDeviceKind.touch) {
      if (_directPointer != null) {
        // A pinch or a scroll, which no long press is part of.
        _stopLongPressWait();
        return;
      }
      _directPointer = event.pointer;
    }
    final point = transform.toRemote(event.localPosition);
    if (point == null) return;
    _buttons = _buttonMask(event.buttons);
    _sendPointer(session, point);
    if (event.kind == ui.PointerDeviceKind.touch) {
      // The left button is down already, as a finger on the picture is a
      // mouse there: let go of it first, then the right click — Windows'
      // own press and hold selects the same way before its menu opens.
      _armLongPress(event.localPosition, () {
        _buttons = 0;
        _sendPointer(session, point);
        _click(session, point, 4);
      });
    }
  }

  void _pointerMove(
    PointerMoveEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    if (session.viewOnly) return;
    if (_touchpad(event)) return _touchpadMove(event, transform, session);
    if (!_isDirectPointer(event)) return;
    _moveLongPress(event.localPosition);
    if (_longPressed) return;
    // Clamped while something is held on the desktop, so a drag that leaves
    // the picture stays pressed at its edge rather than going silent. Only
    // when the desktop was told of the press ([_buttons], the last state
    // sent): a press that landed outside the picture was never sent, and
    // clamping it would press the edge for it.
    final buttons = _buttonMask(event.buttons);
    final point = transform.toRemote(
      event.localPosition,
      clamp: buttons != 0 && _buttons != 0,
    );
    if (point == null) return;
    _buttons = buttons;
    _sendPointer(session, point);
  }

  /// A mouse moving with no button down. Without this the remote pointer
  /// only followed the mouse while a button was held, so nothing on the
  /// desktop knew where it was until something was clicked.
  void _pointerHover(
    PointerHoverEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    _noteInputKind(event.kind);
    if (session.viewOnly) return;
    final point = transform.toRemote(event.localPosition);
    if (point == null) return;
    _buttons = 0;
    _sendPointer(session, point);
  }

  /// A button let go is sent as let go. This used to send a whole click on
  /// the way up — press again, then release — which for a mouse repeated a
  /// press the desktop had already had.
  void _pointerUp(
    PointerUpEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    if (_touchpad(event)) return _touchpadUp(event, transform, session);
    if (!_isDirectPointer(event)) return;
    _directPointer = null;
    if (_endLongPress()) return;
    if (session.viewOnly) return;
    // Clamped: a release outside the picture is still the release.
    final point = transform.toRemote(event.localPosition, clamp: true);
    if (point == null) return;
    _buttons = _buttonMask(event.buttons);
    _sendPointer(session, point);
  }

  /// Whether [event] is the finger the direct path follows. Anything that is
  /// not a finger always is.
  bool _isDirectPointer(PointerEvent event) =>
      event.kind != ui.PointerDeviceKind.touch ||
      event.pointer == _directPointer;

  /// Lets go of anything held, where the pointer already is.
  ///
  /// It sent the touchpad's position in *viewport* coordinates as if they
  /// were desktop pixels, which put the release somewhere else entirely.
  void _pointerCancel(
    PointerCancelEvent event,
    RemoteDesktopSessionView session,
  ) {
    // A finger the direct path was ignoring holds nothing. Cancelling it
    // released the finger that did, mid-drag, and stopped following it.
    if (!_touchpad(event) && !_isDirectPointer(event)) return;
    _resetTouchpad();
    _endLongPress();
    _directPointer = null;
    _buttons = 0;
    final point = _pointer.value;
    if (point != null) _sendPointer(session, point);
  }

  void _pointerSignal(
    PointerSignalEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    if (event is! PointerScrollEvent || session.viewOnly) return;
    final point = transform.toRemote(event.localPosition);
    if (point == null) return;
    ref.read(remoteDesktopSessionsProvider.notifier).sendWheel(
      session.id,
      point.dx.round(),
      point.dy.round(),
      deltaX: (-event.scrollDelta.dx * 8).round(),
      deltaY: (-event.scrollDelta.dy * 8).round(),
    );
  }

  int _buttonMask(int buttons) {
    var mask = 0;
    if (buttons & kPrimaryMouseButton != 0) mask |= 1;
    if (buttons & kMiddleMouseButton != 0) mask |= 2;
    if (buttons & kSecondaryMouseButton != 0) mask |= 4;
    return mask;
  }

  void _sendPointer(RemoteDesktopSessionView session, Offset point) {
    _pointer.value = point;
    ref.read(remoteDesktopSessionsProvider.notifier).sendPointer(
      session.id,
      point.dx.round(),
      point.dy.round(),
      _buttons,
    );
  }
}

enum _TouchMode { trackpad, direct }
