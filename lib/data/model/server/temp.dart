class Temperatures {
  final Map<String, double> _map = {};

  /// Parsing happens in the shared Rust library (sbm_parser::linux::parse_temps); assembly only here
  void setAll(Map<String, double> values) {
    _map
      ..clear()
      ..addAll(values);
  }

  double? get(String name) {
    return _map[name];
  }

  Iterable<String> get devices {
    return _map.keys;
  }

  bool get isEmpty {
    return _map.isEmpty;
  }

  double? get first {
    if (_map.isEmpty) {
      return null;
    }
    for (final key in _cpuTemp) {
      if (_map.containsKey(key)) {
        return _map[key];
      }
    }
    return _map.values.firstOrNull;
  }
}

/// soc: mobile phone
/// cpu_thermal / x86_pkg_temp / coretemp / zenpower: x86
const _cpuTemp = ['x86_pkg_temp', 'coretemp', 'zenpower', 'cpu_thermal', 'soc'];
