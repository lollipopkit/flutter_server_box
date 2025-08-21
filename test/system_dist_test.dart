import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/dist.dart';

void main() {
  group('SystemType Tests', () {
    test('SystemType values and properties', () {
      expect(SystemType.linux.value, equals('__linux'));
      expect(SystemType.bsd.value, equals('__bsd'));
      expect(SystemType.windows.value, equals('__windows'));
    });

    test('SystemType.parse detects Windows', () {
      const windowsOutput = 'System info __windows version 10';
      final result = SystemType.parse(windowsOutput);
      expect(result, equals(SystemType.windows));
    });

    test('SystemType.parse detects BSD', () {
      const bsdOutput = 'FreeBSD 13.0-RELEASE __bsd';
      final result = SystemType.parse(bsdOutput);
      expect(result, equals(SystemType.bsd));
    });

    test('SystemType.parse detects Linux', () {
      const linuxOutput = 'Linux 5.4.0 __linux';
      final result = SystemType.parse(linuxOutput);
      expect(result, equals(SystemType.linux));
    });

    test('SystemType.parse defaults to Linux for empty input', () {
      const emptyOutput = '';
      final result = SystemType.parse(emptyOutput);
      expect(result, equals(SystemType.linux));
    });

    test('SystemType.parse defaults to Linux for unknown output', () {
      const unknownOutput = 'Unknown system output';
      final result = SystemType.parse(unknownOutput);
      expect(result, equals(SystemType.linux));
    });

    test('SystemType.parse handles long strings', () {
      final longOutput = 'a' * 200;
      final result = SystemType.parse(longOutput);
      expect(result, equals(SystemType.linux));
    });
  });

  group('Dist Tests', () {
    test('Dist enum contains all expected values', () {
      expect(Dist.values, contains(Dist.debian));
      expect(Dist.values, contains(Dist.ubuntu));
      expect(Dist.values, contains(Dist.centos));
      expect(Dist.values, contains(Dist.fedora));
      expect(Dist.values, contains(Dist.opensuse));
      expect(Dist.values, contains(Dist.kali));
      expect(Dist.values, contains(Dist.wrt));
      expect(Dist.values, contains(Dist.armbian));
      expect(Dist.values, contains(Dist.arch));
      expect(Dist.values, contains(Dist.alpine));
      expect(Dist.values, contains(Dist.rocky));
      expect(Dist.values, contains(Dist.deepin));
      expect(Dist.values, contains(Dist.coreelec));
    });

    test('String.dist extension detects Debian', () {
      const input = 'debian 10.0';
      final result = input.dist;
      expect(result, equals(Dist.debian));
    });

    test('String.dist extension detects Ubuntu', () {
      const input = 'ubuntu 20.04';
      final result = input.dist;
      expect(result, equals(Dist.ubuntu));
    });

    test('String.dist extension detects CentOS', () {
      const input = 'centos 8';
      final result = input.dist;
      expect(result, equals(Dist.centos));
    });

    test('String.dist extension detects Fedora', () {
      const input = 'fedora 34';
      final result = input.dist;
      expect(result, equals(Dist.fedora));
    });

    test('String.dist extension detects OpenSUSE', () {
      const input = 'opensuse leap 15.3';
      final result = input.dist;
      expect(result, equals(Dist.opensuse));
    });

    test('String.dist extension detects Kali', () {
      const input = 'kali linux 2021.2';
      final result = input.dist;
      expect(result, equals(Dist.kali));
    });

    test('String.dist extension detects WRT special case', () {
      const input = 'istoreos 21.02';
      final result = input.dist;
      expect(result, equals(Dist.wrt));
    });

    test('String.dist extension detects Armbian', () {
      const input = 'armbian 21.08';
      final result = input.dist;
      expect(result, equals(Dist.armbian));
    });

    test('String.dist extension detects Arch', () {
      const input = 'arch linux';
      final result = input.dist;
      expect(result, equals(Dist.arch));
    });

    test('String.dist extension detects Alpine', () {
      const input = 'alpine linux 3.14';
      final result = input.dist;
      expect(result, equals(Dist.alpine));
    });

    test('String.dist extension detects Rocky', () {
      const input = 'rocky linux 8.4';
      final result = input.dist;
      expect(result, equals(Dist.rocky));
    });

    test('String.dist extension detects Deepin', () {
      const input = 'deepin 20';
      final result = input.dist;
      expect(result, equals(Dist.deepin));
    });

    test('String.dist extension detects CoreELEC', () {
      const input = 'coreelec 19.0';
      final result = input.dist;
      expect(result, equals(Dist.coreelec));
    });

    test('String.dist extension is case insensitive', () {
      const input = 'UBUNTU 20.04';
      final result = input.dist;
      expect(result, equals(Dist.ubuntu));
    });

    test('String.dist extension returns null for unknown distribution', () {
      const input = 'unknown distribution';
      final result = input.dist;
      expect(result, isNull);
    });

    test('String.dist extension handles empty string', () {
      const input = '';
      final result = input.dist;
      expect(result, isNull);
    });

    test('String.dist extension handles substring matches', () {
      const input = 'xubuntu 20.04'; // Contains 'ubuntu'
      final result = input.dist;
      expect(result, equals(Dist.ubuntu));
    });

    test('String.dist extension prioritizes exact matches over substring', () {
      const input = 'kali linux'; // Contains 'linux' but 'kali' is more specific
      final result = input.dist;
      expect(result, equals(Dist.kali));
    });

    test('Special WRT cases are handled correctly', () {
      expect('istoreos'.dist, equals(Dist.wrt));
      expect('iStoreOS'.dist, equals(Dist.wrt));
      expect('ISTOREOS'.dist, equals(Dist.wrt));
    });

    test('Distribution detection order follows enum order', () {
      // This test ensures that the first match in the enum is returned
      const input = 'ubuntu'; // This could match both 'ubuntu' and 'kali' (contains 'u')
      final result = input.dist;
      expect(result, equals(Dist.ubuntu)); // ubuntu comes before kali in enum
    });
  });
}