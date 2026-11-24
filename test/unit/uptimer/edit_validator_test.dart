import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/uptimer/state.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/page/uptimer/edit_validator.dart';

void main() {
  setUpAll(() {
    app_locale.l10n = AppLocalizationsEn();
  });

  group('isValidUptimerTcpTarget', () {
    test('accepts IPv4, hostname, and bracketed IPv6 host:port', () {
      expect(isValidUptimerTcpTarget('example.com:443'), isTrue);
      expect(isValidUptimerTcpTarget('127.0.0.1:8080'), isTrue);
      expect(isValidUptimerTcpTarget('[::1]:443'), isTrue);
      expect(isValidUptimerTcpTarget('[2001:db8::1]:65535'), isTrue);
    });

    test('rejects missing/out-of-range port, whitespace, and malformed IPv6', () {
      expect(isValidUptimerTcpTarget(''), isFalse);
      expect(isValidUptimerTcpTarget('example.com'), isFalse);
      expect(isValidUptimerTcpTarget('example.com:0'), isFalse);
      expect(isValidUptimerTcpTarget('example.com:65536'), isFalse);
      expect(isValidUptimerTcpTarget('example.com: 443'), isFalse);
      expect(isValidUptimerTcpTarget('[not-ipv6]:443'), isFalse);
      expect(isValidUptimerTcpTarget('a:b:443'), isFalse);
    });
  });

  group('sanitizeUptimerHeaders', () {
    test('trims keys/values and drops blank keys', () {
      expect(
        sanitizeUptimerHeaders({
          ' Authorization ': ' Bearer x ',
          '   ': 'ignored',
          'X-Test': ' 1 ',
        }),
        {'Authorization': 'Bearer x', 'X-Test': '1'},
      );
    });
  });

  group('UptimerEditControllers & validateAndBuildUptimerPayload', () {
    test('hydrates from config and builds valid HTTP update payload', () {
      final ctrls = UptimerEditControllers();
      addTearDown(ctrls.dispose);

      ctrls.applyConfig(
        const UptimerMonitorConfig(
          id: 7,
          name: 'API',
          type: UptimerMonitorType.http,
          target: 'https://api.example.com/health',
          intervalSec: 180,
          timeoutMs: 5000,
          groupName: 'CORE',
          showOnStatusPage: true,
          isActive: true,
          status: UptimerMonitorStatus.up,
          httpMethod: 'POST',
          followRedirects: false,
          httpBody: '{"ok":true}',
          responseKeyword: ' ok ',
          responseKeywordMode: 'contains',
        ),
      );

      final res = validateAndBuildUptimerPayload(
        isEditing: true,
        type: UptimerMonitorType.http,
        ctrls: ctrls,
        rawGroupName: 'CORE',
        minInterval: 60,
        showOnStatusPage: true,
        submittedActive: true,
        initialIsActive: true,
        initialWasPaused: false,
        httpMethod: 'POST',
        followRedirects: false,
        rawHeaders: const {' X-Key ': ' val '},
        keywordMode: 'contains',
        forbiddenKeywordMode: 'contains',
      );

      expect(res.error, isNull);
      final p = res.payload!;
      expect(p['name'], 'API');
      expect(p['target'], 'https://api.example.com/health');
      expect(p['interval_sec'], 180);
      expect(p['timeout_ms'], 5000);
      expect(p['http_method'], 'POST');
      expect(p['http_headers_json'], {'X-Key': 'val'});
      expect(p['http_body'], '{"ok":true}');
      expect(p['response_keyword'], ' ok ');
      expect(p.containsKey('is_active'), isFalse);
    });

    test('rejects empty name and empty target', () {
      final ctrls = UptimerEditControllers();
      addTearDown(ctrls.dispose);

      final emptyName = validateAndBuildUptimerPayload(
        isEditing: false,
        type: UptimerMonitorType.http,
        ctrls: ctrls,
        rawGroupName: '',
        minInterval: 60,
        showOnStatusPage: false,
        submittedActive: true,
        initialIsActive: true,
        initialWasPaused: false,
        httpMethod: 'GET',
        followRedirects: true,
        rawHeaders: const {},
        keywordMode: 'contains',
        forbiddenKeywordMode: 'contains',
      );
      expect(emptyName.payload, isNull);
      expect(emptyName.error, isNotNull);

      ctrls.name.text = 'Web';
      final emptyTarget = validateAndBuildUptimerPayload(
        isEditing: false,
        type: UptimerMonitorType.http,
        ctrls: ctrls,
        rawGroupName: '',
        minInterval: 60,
        showOnStatusPage: false,
        submittedActive: true,
        initialIsActive: true,
        initialWasPaused: false,
        httpMethod: 'GET',
        followRedirects: true,
        rawHeaders: const {},
        keywordMode: 'contains',
        forbiddenKeywordMode: 'contains',
      );
      expect(emptyTarget.payload, isNull);
      expect(emptyTarget.error, isNotNull);
    });

    test('validates invalid displayUrl, interval, regex, and heartbeat grace', () {
      final ctrls = UptimerEditControllers();
      addTearDown(ctrls.dispose);
      ctrls.name.text = 'Ping';
      ctrls.target.text = 'https://example.com';
      ctrls.displayUrl.text = 'ftp://bad.example.com';

      final badUrl = validateAndBuildUptimerPayload(
        isEditing: false,
        type: UptimerMonitorType.http,
        ctrls: ctrls,
        rawGroupName: '',
        minInterval: 60,
        showOnStatusPage: false,
        submittedActive: true,
        initialIsActive: true,
        initialWasPaused: false,
        httpMethod: 'GET',
        followRedirects: true,
        rawHeaders: const {},
        keywordMode: 'contains',
        forbiddenKeywordMode: 'contains',
      );
      expect(badUrl.payload, isNull);
      expect(badUrl.error, isNotNull);

      ctrls.displayUrl.text = '';
      ctrls.interval.text = '30';
      final badInterval = validateAndBuildUptimerPayload(
        isEditing: false,
        type: UptimerMonitorType.http,
        ctrls: ctrls,
        rawGroupName: '',
        minInterval: 60,
        showOnStatusPage: false,
        submittedActive: true,
        initialIsActive: true,
        initialWasPaused: false,
        httpMethod: 'GET',
        followRedirects: true,
        rawHeaders: const {},
        keywordMode: 'contains',
        forbiddenKeywordMode: 'contains',
      );
      expect(badInterval.payload, isNull);

      ctrls.interval.text = '60';
      ctrls.keyword.text = '[unclosed';
      final badRegex = validateAndBuildUptimerPayload(
        isEditing: false,
        type: UptimerMonitorType.http,
        ctrls: ctrls,
        rawGroupName: '',
        minInterval: 60,
        showOnStatusPage: false,
        submittedActive: true,
        initialIsActive: true,
        initialWasPaused: false,
        httpMethod: 'GET',
        followRedirects: true,
        rawHeaders: const {},
        keywordMode: 'regex',
        forbiddenKeywordMode: 'contains',
      );
      expect(badRegex.payload, isNull);

      ctrls.keyword.text = '';
      ctrls.grace.text = '90000';
      final badGrace = validateAndBuildUptimerPayload(
        isEditing: false,
        type: UptimerMonitorType.heartbeat,
        ctrls: ctrls,
        rawGroupName: '',
        minInterval: 60,
        showOnStatusPage: false,
        submittedActive: true,
        initialIsActive: true,
        initialWasPaused: false,
        httpMethod: 'GET',
        followRedirects: true,
        rawHeaders: const {},
        keywordMode: 'contains',
        forbiddenKeywordMode: 'contains',
      );
      expect(badGrace.payload, isNull);
    });
  });

  group('UptimerState', () {
    test('computeSortedGroups deduplicates, ignores blank, and sorts', () {
      const m1 = UptimerMonitorCard(
        id: 1,
        name: 'A',
        type: UptimerMonitorType.http,
        status: UptimerMonitorStatus.up,
        groupName: 'OPS',
      );
      const m2 = UptimerMonitorCard(
        id: 2,
        name: 'B',
        type: UptimerMonitorType.tcp,
        status: UptimerMonitorStatus.down,
        groupName: 'API',
      );
      const m3 = UptimerMonitorCard(
        id: 3,
        name: 'C',
        type: UptimerMonitorType.heartbeat,
        status: UptimerMonitorStatus.up,
        groupName: '',
      );
      final sorted = UptimerState.computeSortedGroups(const {
        1: m1,
        2: m2,
        3: m3,
      });
      expect(sorted, ['API', 'OPS']);

      final state = UptimerState(
        userId: 'u1',
        monitors: const {1: m1, 2: m2, 3: m3},
        sortedGroupNames: sorted,
      );
      expect(state.signedIn, isTrue);
      expect(state.hasAlert(2), isTrue);
      expect(state.hasAlert(1), isFalse);
      expect(state.copyWith(userId: null).signedIn, isFalse);
    });
  });
}
