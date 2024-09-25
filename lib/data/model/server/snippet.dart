import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:xterm/core.dart';

part 'snippet.g.dart';

@JsonSerializable()
@HiveType(typeId: 2)
class Snippet {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String script;
  @HiveField(2)
  final List<String>? tags;
  @HiveField(3)
  final String? note;

  /// List of server id that this snippet should be auto run on
  @HiveField(4)
  final List<String>? autoRunOn;

  const Snippet({
    required this.name,
    required this.script,
    this.tags,
    this.note,
    this.autoRunOn,
  });

  factory Snippet.fromJson(Map<String, dynamic> json) =>
      _$SnippetFromJson(json);

  Map<String, dynamic> toJson() => _$SnippetToJson(this);

  static final fmtFinder = RegExp(r'\$\{[^{}]+\}');

  String fmtWithSpi(Spi spi) {
    return script.replaceAllMapped(
      fmtFinder,
      (match) {
        final key = match.group(0);
        final func = fmtArgs[key];
        if (func != null) return func(spi);
        // If not found, return the original content for further processing
        return key ?? '';
      },
    );
  }

  Future<void> runInTerm(
    Terminal terminal,
    Spi spi, {
    bool autoEnter = false,
  }) async {
    final argsFmted = fmtWithSpi(spi);
    final matches = fmtFinder.allMatches(argsFmted);

    /// There is no [TerminalKey] in the script
    if (matches.isEmpty) {
      terminal.textInput(argsFmted);
      if (autoEnter) terminal.keyInput(TerminalKey.enter);
      return;
    }

    // Records all start and end indexes of the matches
    final (starts, ends) = matches.fold((<int>[], <int>[]), (pre, e) {
      pre.$1.add(e.start);
      pre.$2.add(e.end);
      return pre;
    });

    // Check all indexes, `(idx + 1).start` must >= `idx.end`
    for (var i = 0; i < starts.length - 1; i++) {
      final lastEnd = ends[i];
      final nextStart = starts[i + 1];
      if (nextStart < lastEnd) {
        throw 'Invalid format: $nextStart < $lastEnd';
      }
    }

    // Start term input
    if (starts.first > 0) {
      terminal.textInput(argsFmted.substring(0, starts.first));
    }

    // Process matched
    for (var idx = 0; idx < starts.length; idx++) {
      final start = starts[idx];
      final end = ends[idx];
      final key = argsFmted.substring(start, end).toLowerCase();

      // Special funcs
      final special = _find(SnippetFuncs.specialCtrl, key);
      if (special != null) {
        final raw = key.substring(special.key.length + 1, key.length - 1);
        await special.value((term: terminal, raw: raw));
      } else {
        // Term keys
        final termKey = _find(fmtTermKeys, key);
        if (termKey != null) {
          await _doTermKeys(terminal, termKey, key);
        } else {
          // Normal input
          terminal.textInput(key);
        }
      }

      // Text between this and next match
      if (idx < starts.length - 1) {
        terminal.textInput(argsFmted.substring(end, starts[idx + 1]));
      }
    }

    // End term input
    if (ends.last < argsFmted.length) {
      terminal.textInput(argsFmted.substring(ends.last));
    }

    if (autoEnter) terminal.keyInput(TerminalKey.enter);
  }

  Future<void> _doTermKeys(
    Terminal terminal,
    MapEntry<String, TerminalKey> termKey,
    String key,
  ) async {
    // if (termKey.value == TerminalKey.enter) {
    //   terminal.keyInput(TerminalKey.enter);
    //   return;
    // }

    final ctrlAlt = switch (termKey.value) {
      TerminalKey.control => (ctrl: true, alt: false),
      TerminalKey.alt => (ctrl: false, alt: true),
      _ => (ctrl: false, alt: false),
    };

    if (!key.contains('+')) return;

    // `${ctrl+ad}` -> `ctrla + d`
    final chars = key.substring(termKey.key.length + 1, key.length - 1);
    if (chars.isEmpty) return;
    final ok = terminal.charInput(
      chars.codeUnitAt(0),
      ctrl: ctrlAlt.ctrl,
      alt: ctrlAlt.alt,
    );
    if (!ok) {
      Loggers.app.warning('Failed to input: $key');
    }

    terminal.textInput(chars.substring(1));
  }

  MapEntry<String, T>? _find<T>(Map<String, T> map, String key) {
    return map.entries.firstWhereOrNull((e) => key.startsWith(e.key));
  }

  static final fmtArgs = {
    r'${host}': (Spi spi) => spi.ip,
    r'${port}': (Spi spi) => spi.port.toString(),
    r'${user}': (Spi spi) => spi.user,
    r'${pwd}': (Spi spi) => spi.pwd ?? '',
    r'${id}': (Spi spi) => spi.id,
    r'${name}': (Spi spi) => spi.name,
  };

  /// r'${ctrl+ad}' -> TerminalKey.control, a, d
  static final fmtTermKeys = {
    r'${ctrl': TerminalKey.control,
    r'${alt': TerminalKey.alt,
  };

  static const example = Snippet(
    name: 'example',
    script: 'echo hello',
    tags: ['tag'],
    note: 'note',
    autoRunOn: ['server_id'],
  );
}

class SnippetResult {
  final String? dest;
  final String result;
  final Duration time;

  SnippetResult({
    required this.dest,
    required this.result,
    required this.time,
  });
}

typedef SnippetFuncCtx = ({Terminal term, String raw});

abstract final class SnippetFuncs {
  static final specialCtrl = {
    // `${sleep 3}` -> sleep 3 seconds
    r'${sleep': SnippetFuncs.sleep,
    r'${enter': SnippetFuncs.enter,
  };

  static const help = {
    'sleep': 'Sleep for a few seconds',
    'enter': 'Enter a few times',
  };

  static FutureOr<void> sleep(SnippetFuncCtx ctx) async {
    final seconds = int.tryParse(ctx.raw);
    if (seconds == null) return;
    final duration = Duration(seconds: seconds);
    await Future.delayed(duration);
  }

  static FutureOr<void> enter(SnippetFuncCtx ctx) async {
    final times = int.tryParse(ctx.raw) ?? 1;
    for (var i = 0; i < times; i++) {
      ctx.term.keyInput(TerminalKey.enter);
    }
  }
}
