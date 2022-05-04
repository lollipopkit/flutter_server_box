import 'package:toolbox/data/model/distribution.dart';

extension StringX on String {
  int get i => int.parse(this);

  Distribution get dist {
    final lower = toLowerCase();
    for (var dist in debianDistList) {
      if (lower.contains(dist)) {
        return Distribution.debian;
      }
    }
    for (var dist in rehlDistList) {
      if (lower.contains(dist)) {
        return Distribution.rehl;
      }
    }
    return Distribution.unknown;
  }

  Uri get uri {
    return Uri.parse(this);
  }
}
