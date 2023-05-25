class Temperatures {
  final Map<String, double> _map = {};

  Temperatures();

  void parse(String type, String value) {
    const noMatch = "/sys/class/thermal/thermal_zone*/type";
    // Not support to get CPU temperature
    if (type.contains(noMatch) || value.isEmpty || type.isEmpty) {
      return;
    }
    final typeSplited = type.split('\n');
    final valueSplited = value.split('\n');
    if (typeSplited.length != valueSplited.length) {
      return;
    }
    for (var i = 0; i < typeSplited.length; i++) {
      final t = typeSplited[i];
      final v = valueSplited[i];
      if (t.isEmpty || v.isEmpty) {
        continue;
      }
      final name = t.split('/').last;
      final temp = double.tryParse(v);
      if (temp == null) {
        continue;
      }
      _map[name] = temp / 1000;
    }
  }

  void add(String name, double value) {
    _map[name] = value;
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
    for (final key in _map.keys) {
      if (cpuTempReg.hasMatch(key)) {
        return _map[key];
      }
    }
    return _map.values.first;
  }
}

final cpuTempReg = RegExp(r'(x86_pkg_temp|cpu_thermal)');
