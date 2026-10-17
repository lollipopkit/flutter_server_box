import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/ssh/terminal_a11y.dart';
import 'package:xterm/core.dart';

/// A terminal's output as plain text: one line per row, selectable, and in
/// the semantics tree, which the terminal's own canvas is not.
///
/// Follows the terminal while open, without scrolling: where the reader is
/// stays theirs.
final class TerminalTextPage extends StatefulWidget {
  const TerminalTextPage({super.key, required this.args});

  final Terminal args;

  static const route = AppRouteArg<void, Terminal>(
    page: TerminalTextPage.new,
    path: '/ssh/text',
  );

  @override
  State<TerminalTextPage> createState() => _TerminalTextPageState();
}

final class _TerminalTextPageState extends State<TerminalTextPage> {
  Terminal get _terminal => widget.args;

  /// One per buffer: a full-screen program draws on the alternate one, and
  /// leaving it brings the main one back as it was.
  final _transcripts = <Buffer, TerminalTranscript>{};

  List<String> _lines = const [];
  var _letGo = 0;
  Timer? _throttle;

  TerminalTranscript get _transcript {
    final buffer = _terminal.buffer;
    return _transcripts[buffer] ??= TerminalTranscript(buffer);
  }

  @override
  void initState() {
    super.initState();
    _sync();
    _terminal.addListener(_onChange);
  }

  @override
  void dispose() {
    _terminal.removeListener(_onChange);
    _throttle?.cancel();
    for (final transcript in _transcripts.values) {
      transcript.dispose();
    }
    super.dispose();
  }

  /// At most a few times a second: output arrives in chunks far smaller than
  /// a line, and every one is a rebuild of the list.
  void _onChange() {
    _throttle ??= Timer(const Duration(milliseconds: 250), () {
      _throttle = null;
      if (mounted) setState(_sync);
    });
  }

  void _sync() {
    final transcript = _transcript..sync();
    _lines = transcript.lines;
    _letGo = transcript.letGo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.termTextView)),
      body: SelectionArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          itemCount: _lines.length + (_letGo > 0 ? 1 : 0),
          itemBuilder: (context, i) {
            if (_letGo > 0) {
              if (i == 0) {
                return Text(
                  l10n.termTextLetGo(_letGo),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              }
              i--;
            }
            return Text(
              _lines[i],
              style: const TextStyle(fontFamily: 'monospace'),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: FilledButton(
            onPressed: () => context.pop(),
            child: Text(libL10n.close),
          ),
        ),
      ),
    );
  }
}
