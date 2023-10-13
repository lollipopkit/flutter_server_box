class Temperatures {
  final Map<String, double> _map = {};

  void parse(String type, String value) {
    final typeSplited = type.split('\n');
    final valueSplited = value.split('\n');
    for (var i = 0; i < typeSplited.length && i < valueSplited.length; i++) {
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

/// soc: mobile phone
/// cpu_thermal / x86_pkg_temp: x86
final cpuTempReg = RegExp(r'(x86_pkg_temp|cpu_thermal|soc)');
