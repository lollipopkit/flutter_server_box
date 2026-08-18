import 'package:fl_lib/fl_lib.dart';

enum SystemType {
  linux(linuxSign),
  bsd(bsdSign),
  windows(windowsSign);

  final String? value;

  const SystemType([this.value]);

  static const linuxSign = '__linux';
  static const bsdSign = '__bsd';
  static const windowsSign = '__windows';

  /// The name `sbm_parser::SystemType` serialises to, as a `monitor` agent
  /// reports it — the agent knows what it is running on, so nothing has to be
  /// detected by running a command there.
  ///
  /// Null for a name this app does not know, which is the answer that keeps a
  /// newer agent from being read as Linux.
  static SystemType? fromWire(String? name) => switch (name) {
    'linux' => linux,
    'bsd' => bsd,
    'windows' => windows,
    _ => null,
  };

  /// Used for parsing system types from shell output.
  ///
  /// This method looks for specific system signatures in the shell output
  /// and returns the corresponding SystemType. If no signature is found,
  /// it defaults to Linux but logs the detection failure for debugging.
  static SystemType parse(String value) {
    // Log the raw value for debugging purposes (truncated to avoid spam)
    final truncatedValue = value.length > 100
        ? '${value.substring(0, 100)}...'
        : value;

    if (value.contains(windowsSign)) {
      Loggers.app.info(
        'System detected as Windows from signature in: $truncatedValue',
      );
      return SystemType.windows;
    }
    if (value.contains(bsdSign)) {
      Loggers.app.info(
        'System detected as BSD from signature in: $truncatedValue',
      );
      return SystemType.bsd;
    }

    // Log when falling back to Linux detection
    if (value.trim().isEmpty) {
      Loggers.app.warning(
        'System detection received empty input, defaulting to Linux. '
        'This may indicate a script execution issue.',
      );
    } else if (!value.contains(linuxSign)) {
      Loggers.app.warning(
        'System detection could not find any known signatures (Windows: $windowsSign, '
        'BSD: $bsdSign, Linux: $linuxSign) in output: "$truncatedValue". '
        'Defaulting to Linux, but this may cause incorrect parsing.',
      );
    } else {
      Loggers.app.info(
        'System detected as Linux from signature in: $truncatedValue',
      );
    }

    return SystemType.linux;
  }
}
