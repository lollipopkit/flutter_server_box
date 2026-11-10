import 'package:server_box/src/rust/api/parser.dart' as rs show SystemType;

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

  /// This platform as `sbm_parser` takes it over FFI.
  rs.SystemType get ffi => switch (this) {
    linux => rs.SystemType.linux,
    bsd => rs.SystemType.bsd,
    windows => rs.SystemType.windows,
  };

  /// [system], as `sbm_parser` reported it.
  static SystemType of(rs.SystemType system) => switch (system) {
    rs.SystemType.linux => linux,
    rs.SystemType.bsd => bsd,
    rs.SystemType.windows => windows,
  };
}
