import 'package:flutter/material.dart';
import 'package:server_box/data/res/terminal.dart';
import 'package:xterm/xterm.dart';

/// A benchmark's output, rendered by a terminal.
///
/// yabs animates its progress: it prints `Preparing system for disk tests...`,
/// then `\r` and `\e[0K` to erase the line and print the next step over it. As
/// plain text that reads as
/// `Preparing system for disk tests... ␛[0KGenerating fio test file... ␛[0K…`
/// — every step ever printed, run together, with the escape codes shown as
/// mojibake. A terminal is not decoration here; it is the only thing that
/// renders what the script actually meant to say.
///
/// The app already ships one (`packages/xterm`), so this is the fork the SSH
/// pages use, in read-only mode.
class BenchmarkLogView extends StatefulWidget {
  const BenchmarkLogView({super.key, required this.log, this.height = 260});

  /// The whole log so far. Each poll brings the whole thing rather than a
  /// delta, and [didUpdateWidget] works out what is new.
  final String log;

  final double height;

  @override
  State<BenchmarkLogView> createState() => _BenchmarkLogViewState();
}

class _BenchmarkLogViewState extends State<BenchmarkLogView> {
  late Terminal _terminal;
  final _controller = TerminalController();

  /// What has already been written, so an update only writes the rest.
  ///
  /// Writing the whole log every time would repeat it once per poll, and the
  /// cursor movements in it would then be replayed against the wrong lines.
  var _written = '';

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 4000);
    _append(widget.log);
  }

  @override
  void didUpdateWidget(BenchmarkLogView old) {
    super.didUpdateWidget(old);
    if (widget.log == _written) return;
    if (widget.log.startsWith(_written)) {
      _append(widget.log.substring(_written.length));
      return;
    }
    // Not an extension of what was shown — a different run, or one whose
    // directory was recreated. Start again rather than write output that would
    // be interpreted against a screen it was not drawn for.
    _terminal = Terminal(maxLines: 4000);
    _written = '';
    _append(widget.log);
  }

  void _append(String chunk) {
    if (chunk.isEmpty) return;
    // The log is a file, not a pty, so its lines end in `\n` alone. A terminal
    // reads that as "down one row" and not "back to column one", which
    // staircases the whole output down and to the right. Normalised first so a
    // `\r\n` that is already there does not become `\r\r\n`.
    _terminal.write(chunk.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n'));
    _written += chunk;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: TerminalView(
          _terminal,
          controller: _controller,
          theme: TerminalLook.themeOf(context),
          textStyle: TerminalLook.style,
          padding: const EdgeInsets.all(8),
          // Nothing here types: this is a transcript of a run happening on
          // another machine, and there is no channel to send a keystroke down.
          readOnly: true,
          cursorBlink: false,
          autofocus: false,
          autoResize: true,
        ),
      ),
    );
  }
}
