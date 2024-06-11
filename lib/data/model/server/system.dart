import 'package:server_box/data/model/app/shell_func.dart';

enum SystemType {
  linux._(linuxSign),
  bsd._(bsdSign),
  ;

  final String value;

  const SystemType._(this.value);

  static const linuxSign = '__linux';
  static const bsdSign = '__bsd';

  static SystemType parse(String value) {
    if (value.contains(bsdSign)) {
      return SystemType.bsd;
    }
    return SystemType.linux;
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
