import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;
import 'package:server_box/view/page/remote_desktop/frame_decoder.dart';
import 'package:server_box/view/page/remote_desktop/geometry.dart';
import 'package:server_box/view/page/remote_desktop/input.dart';

class RemoteDesktopViewer extends ConsumerStatefulWidget {
  const RemoteDesktopViewer({
    super.key,
    required this.sessionId,
    this.fullScreen = false,
  });

  final String sessionId;
  final bool fullScreen;

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
  Offset _remotePointer = Offset.zero;
  int _buttons = 0;
  int _touches = 0;
  int _maxTouches = 0;
  bool _touchMoved = false;
  Offset? _lastTouch;
  _TouchMode _touchMode = _TouchMode.trackpad;
  double _scaleStart = 1;
  Timer? _resizeTimer;
  Size? _lastResizeViewport;

  @override
  void initState() {
    super.initState();
    _frame = RemoteDesktopFrameDecoder();
    _keyboardFocus = FocusNode(onKeyEvent: _onKeyEvent);
    _keyboardFocus.addListener(_onFocusChanged);
    _imeFocus = FocusNode();
    _imeController = TextEditingController();
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
    _remotePointer = Offset.zero;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _lastResizeViewport = null;
    _frame.reset();
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    _input?.releaseAll();
    _keyboardFocus.removeListener(_onFocusChanged);
    _keyboardFocus.dispose();
    _imeFocus.dispose();
    _imeController.dispose();
    _frame.dispose();
    if (widget.fullScreen && isMobile) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_keyboardFocus.hasFocus) _input?.releaseAll();
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    final session = ref.read(remoteDesktopSessionsProvider).sessions[widget.sessionId];
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
      remoteDesktopSessionsProvider.select((state) => state.sessions[widget.sessionId]),
    );
    if (session == null) return const SizedBox.shrink();
    _ensureInput(session);
    final pixels = session.frameBgra;
    if (pixels != null && session.width > 0 && session.height > 0) {
      _frame.submit(
        pixels: pixels,
        width: session.width,
        height: session.height,
        sequence: session.frameSequence,
      );
    }
    return ColoredBox(
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

  Widget _toolbar(RemoteDesktopSessionView session) {
    final notifier = ref.read(remoteDesktopSessionsProvider.notifier);
    final connected = session.connectionState ==
        ffi.RemoteDesktopConnectionState.connected;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 44,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = remoteDesktopUsesCompactToolbar(constraints.maxWidth);
            return Row(
              children: [
            const SizedBox(width: 8),
            _connectionDot(session.connectionState),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                session.profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!compact) ...[
              IconButton(
                tooltip: 'Fit to window',
                onPressed: () => setState(() {
                  _scaleMode = RemoteDesktopScaleMode.fit;
                  _pan = Offset.zero;
                }),
                icon: Icon(
                  Icons.fit_screen,
                  color: _scaleMode == RemoteDesktopScaleMode.fit
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              IconButton(
                tooltip: 'Actual size',
                onPressed: () => setState(() {
                  _scaleMode = RemoteDesktopScaleMode.actual;
                  _pan = Offset.zero;
                }),
                icon: Icon(
                  Icons.one_x_mobiledata,
                  color: _scaleMode == RemoteDesktopScaleMode.actual
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              PopupMenuButton<double>(
                tooltip: 'Zoom',
                icon: const Icon(Icons.zoom_in),
                onSelected: (value) => setState(() {
                  _customScale = value;
                  _scaleMode = RemoteDesktopScaleMode.custom;
                }),
                itemBuilder: (_) => [
                  for (final zoom in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                    PopupMenuItem(value: zoom, child: Text('${(zoom * 100).round()}%')),
                ],
              ),
            ],
            IconButton(
              tooltip: session.viewOnly ? 'Disable view only' : 'View only',
              onPressed: () => notifier.setViewOnly(session.id, !session.viewOnly),
              icon: Icon(session.viewOnly ? Icons.visibility : Icons.mouse),
            ),
            if (!compact)
              IconButton(
                tooltip: 'Send clipboard text',
                onPressed: connected && !session.viewOnly
                    ? () => _sendClipboard(session)
                    : null,
                icon: const Icon(Icons.content_paste),
              ),
            IconButton(
              tooltip: 'Show keyboard',
              onPressed: session.viewOnly ? null : _showKeyboard,
              icon: const Icon(Icons.keyboard),
            ),
            PopupMenuButton<_ViewerAction>(
              tooltip: 'More controls',
              onSelected: (action) => _runAction(action, session),
              itemBuilder: (_) => [
                if (compact)
                  const PopupMenuItem(
                    value: _ViewerAction.fit,
                    child: Text('Fit to window'),
                  ),
                if (compact)
                  const PopupMenuItem(
                    value: _ViewerAction.actual,
                    child: Text('Actual size'),
                  ),
                if (compact)
                  const PopupMenuItem(
                    value: _ViewerAction.clipboard,
                    child: Text('Send clipboard text'),
                  ),
                if (isMobile)
                  PopupMenuItem(
                    value: _ViewerAction.touchMode,
                    child: Text(
                      _touchMode == _TouchMode.trackpad
                          ? 'Use direct pointer'
                          : 'Use touchpad pointer',
                    ),
                  ),
                const PopupMenuItem(
                  value: _ViewerAction.ctrlAltDelete,
                  child: Text('Send Ctrl+Alt+Delete'),
                ),
                const PopupMenuItem(
                  value: _ViewerAction.reconnect,
                  child: Text('Reconnect'),
                ),
                const PopupMenuItem(
                  value: _ViewerAction.fullScreen,
                  child: Text('Full screen'),
                ),
                const PopupMenuItem(
                  value: _ViewerAction.close,
                  child: Text('Close session'),
                ),
              ],
            ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _connectionDot(ffi.RemoteDesktopConnectionState state) {
    final color = switch (state) {
      ffi.RemoteDesktopConnectionState.connected => Colors.green,
      ffi.RemoteDesktopConnectionState.connecting ||
      ffi.RemoteDesktopConnectionState.reconnecting => Colors.orange,
      ffi.RemoteDesktopConnectionState.disconnected => Colors.red,
    };
    return Tooltip(
      message: state.name,
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
            const SnackBar(content: Text('VNC clipboard supports Latin-1 text only.')),
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

  Future<void> _runAction(
    _ViewerAction action,
    RemoteDesktopSessionView session,
  ) async {
    final notifier = ref.read(remoteDesktopSessionsProvider.notifier);
    switch (action) {
      case _ViewerAction.fit:
        setState(() {
          _scaleMode = RemoteDesktopScaleMode.fit;
          _pan = Offset.zero;
        });
      case _ViewerAction.actual:
        setState(() {
          _scaleMode = RemoteDesktopScaleMode.actual;
          _pan = Offset.zero;
        });
      case _ViewerAction.clipboard:
        await _sendClipboard(session);
      case _ViewerAction.touchMode:
        setState(() {
          _touchMode = _touchMode == _TouchMode.trackpad
              ? _TouchMode.direct
              : _TouchMode.trackpad;
        });
      case _ViewerAction.ctrlAltDelete:
        if (!session.viewOnly) _sendCtrlAltDelete(session);
      case _ViewerAction.reconnect:
        await notifier.reconnect(session.id);
      case _ViewerAction.fullScreen:
        await _toggleFullScreen();
      case _ViewerAction.close:
        if (widget.fullScreen && mounted) Navigator.of(context).pop();
        await notifier.close(session.id);
    }
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
        final transform = RemoteDesktopViewportTransform.calculate(
          viewport: viewport,
          desktop: desktop,
          mode: _scaleMode,
          customScale: _customScale,
          pan: _pan,
        );
        return Focus(
          focusNode: _keyboardFocus,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _pointerDown(event, transform, session),
            onPointerMove: (event) => _pointerMove(event, transform, session),
            onPointerUp: (event) => _pointerUp(event, transform, session),
            onPointerCancel: (event) => _pointerCancel(session),
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
                  final point = transform.toRemote(_remotePointer, clamp: true);
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
        ? 'Certificate confirmation required'
        : session.error ?? switch (session.connectionState) {
            ffi.RemoteDesktopConnectionState.connecting => 'Connecting…',
            ffi.RemoteDesktopConnectionState.reconnecting =>
              'Reconnecting (${session.reconnectAttempt}/3)…',
            ffi.RemoteDesktopConnectionState.connected => 'Waiting for desktop…',
            ffi.RemoteDesktopConnectionState.disconnected => 'Disconnected',
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }

  void _scheduleResize(RemoteDesktopSessionView session, Size viewport) {
    if (session.profile.protocol != RemoteDesktopProtocol.rdp ||
        viewport.isEmpty ||
        viewport == _lastResizeViewport) {
      return;
    }
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

  void _pointerDown(
    PointerDownEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    _keyboardFocus.requestFocus();
    if (session.viewOnly) return;
    if (event.kind == ui.PointerDeviceKind.touch) {
      _touches++;
      _maxTouches = math.max(_maxTouches, _touches);
      if (_touches == 1) _touchMoved = false;
      _lastTouch = event.localPosition;
      if (_touches > 1) return;
    }
    final trackpad = isMobile &&
        event.kind == ui.PointerDeviceKind.touch &&
        _touchMode == _TouchMode.trackpad;
    final point = trackpad
        ? transform.toRemote(_remotePointer, clamp: true)
        : transform.toRemote(event.localPosition);
    if (point == null) return;
    if (!trackpad) _remotePointer = event.localPosition;
    _buttons = trackpad ? 0 : _buttonMask(event.buttons);
    _sendPointer(session, point);
  }

  void _pointerMove(
    PointerMoveEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    if (session.viewOnly) return;
    Offset local = event.localPosition;
    if (isMobile &&
        event.kind == ui.PointerDeviceKind.touch &&
        _touchMode == _TouchMode.trackpad) {
      if (_touches != 1) return;
      final previous = _lastTouch ?? local;
      _lastTouch = local;
      final delta = local - previous;
      if (delta.distance > 1) _touchMoved = true;
      _remotePointer += delta;
      local = _remotePointer;
    } else {
      _remotePointer = local;
    }
    final point = transform.toRemote(local, clamp: isMobile);
    if (point == null) return;
    _buttons = _buttonMask(event.buttons);
    _sendPointer(session, point);
  }

  void _pointerUp(
    PointerUpEvent event,
    RemoteDesktopViewportTransform transform,
    RemoteDesktopSessionView session,
  ) {
    if (event.kind == ui.PointerDeviceKind.touch) {
      _touches = math.max(0, _touches - 1);
      if (_touches > 0) return;
      _lastTouch = null;
    }
    if (session.viewOnly) return;
    final trackpad = isMobile &&
        event.kind == ui.PointerDeviceKind.touch &&
        _touchMode == _TouchMode.trackpad;
    final local = trackpad
        ? _remotePointer
        : event.localPosition;
    final point = transform.toRemote(local, clamp: isMobile);
    if (point == null) return;
    final tapped = trackpad
        ? (_maxTouches >= 2 && !_touchMoved ? 4 : (!_touchMoved ? 1 : 0))
        : (_buttons == 0 ? 1 : _buttons);
    _maxTouches = 0;
    _touchMoved = false;
    if (tapped == 0) return;
    _buttons = tapped;
    _sendPointer(session, point);
    _buttons = 0;
    _sendPointer(session, point);
  }

  void _pointerCancel(RemoteDesktopSessionView session) {
    _touches = 0;
    _maxTouches = 0;
    _touchMoved = false;
    _lastTouch = null;
    _buttons = 0;
    final point = Offset(
      _remotePointer.dx.clamp(0, math.max(0, session.width - 1)),
      _remotePointer.dy.clamp(0, math.max(0, session.height - 1)),
    );
    _sendPointer(session, point);
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
    ref.read(remoteDesktopSessionsProvider.notifier).sendPointer(
      session.id,
      point.dx.round(),
      point.dy.round(),
      _buttons,
    );
  }
}

bool remoteDesktopUsesCompactToolbar(double width) => width < 650;

enum _TouchMode { trackpad, direct }

enum _ViewerAction {
  fit,
  actual,
  clipboard,
  touchMode,
  ctrlAltDelete,
  reconnect,
  fullScreen,
  close,
}
