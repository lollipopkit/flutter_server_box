import 'package:toolbox/data/model/app/shell_func.dart';

enum SystemType {
  linux._(linuxSign),
  bsd._(bsdSign),
  ;

  final String value;

  const SystemType._(this.value);

  static SystemType? parse(String? value) {
    if (value == null) return null;
    switch (value) {
      case linuxSign:
        return SystemType.linux;
      case bsdSign:
        return SystemType.bsd;
    }
    return null;
  }

  bool isSegmentsLenMatch(int len) => len == segmentsLen;

  int get segmentsLen {
    switch (this) {
      case SystemType.linux:
        return StatusCmdType.values.length;
      case SystemType.bsd:
        return BSDStatusCmdType.values.length;
    }
  }
}

const linuxSign = 'linux';
const bsdSign = 'bsd';
