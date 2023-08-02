import '../../res/server_cmd.dart';

class AppShellFunc {
  final String name;
  final String cmd;
  final String flag;

  const AppShellFunc(this.name, this.cmd, this.flag);

  String get exec => 'sh $shellPath -$flag';
}

typedef AppShellFuncs = List<AppShellFunc>;

extension AppShellFuncsExt on AppShellFuncs {
  String get generate {
    final sb = StringBuffer();
    // Write each func
    for (final func in this) {
      sb.write('''
${func.name}() {
${func.cmd}
}

''');
    }

    // Write switch case
    sb.write('case \$1 in\n');
    for (final func in this) {
      sb.write('''
  '-${func.flag}')
    ${func.name}
    ;;
''');
    }
    sb.write('''
  *)
    echo "Invalid argument \$1"
    ;;
esac
''');
    return sb.toString();
  }
}

// enum AppShellFuncType {
//   status,
//   docker;
// }
