import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/ai/ai_safety.dart';

void main() {
  group('AiSafety.redact', () {
    test('redacts private key blocks', () {
      const input = '''before
-----BEGIN PRIVATE KEY-----
abc
-----END PRIVATE KEY-----
after''';
      final out = AiSafety.redact(input);
      expect(out, contains('<PRIVATE_KEY_BLOCK>'));
      expect(out, isNot(contains('BEGIN PRIVATE KEY')));
    });

    test('redacts Bearer tokens', () {
      const input = 'Authorization: Bearer abc.def.ghi\nnext';
      final out = AiSafety.redact(input);
      expect(out, contains('Authorization: Bearer <TOKEN>'));
      expect(out, isNot(contains('abc.def.ghi')));
    });

    test('redacts OpenAI-style keys', () {
      const input = 'sk-1234567890abcdef1234567890abcdef';
      final out = AiSafety.redact(input);
      expect(out, contains('<API_KEY>'));
      expect(out, isNot(contains('sk-123456')));
    });

    test('replaces Spi identity with placeholders', () {
      final spi = Spi(name: 'n', ip: '192.168.1.2', port: 22, user: 'root', id: 'id');
      const input = 'ssh root@192.168.1.2 -p 22 && echo root && ping 192.168.1.2';
      final out = AiSafety.redact(input, spi: spi);
      expect(out, contains('<USER_AT_HOST>'));
      expect(out, contains('<IP>'));
      expect(out, isNot(contains('root@192.168.1.2')));
      expect(out, isNot(contains('192.168.1.2')));
      // Note: "root" may appear elsewhere and gets replaced.
      expect(out, isNot(contains('echo root')));
    });

    test('none mode returns input unchanged', () {
      const input = 'hello sk-1234567890abcdef';
      final out = AiSafety.redact(input, mode: AiRedactionMode.none);
      expect(out, input);
    });
  });

  group('AiSafety.classifyRisk', () {
    test('detects high risk rm -rf', () {
      expect(AiSafety.classifyRisk('rm -rf /'), AiCommandRisk.high);
      expect(AiSafety.classifyRisk('sudo rm -rf /var/lib/docker'), AiCommandRisk.high);
    });

    test('detects high risk mkfs', () {
      expect(AiSafety.classifyRisk('mkfs.ext4 /dev/sda1'), AiCommandRisk.high);
    });

    test('detects medium risk reboot', () {
      expect(AiSafety.classifyRisk('reboot'), AiCommandRisk.medium);
    });

    test('detects medium risk systemctl restart', () {
      expect(AiSafety.classifyRisk('systemctl restart nginx'), AiCommandRisk.medium);
    });

    test('defaults to low risk', () {
      expect(AiSafety.classifyRisk('ls -la'), AiCommandRisk.low);
      expect(AiSafety.classifyRisk(''), AiCommandRisk.low);
    });
  });
}
